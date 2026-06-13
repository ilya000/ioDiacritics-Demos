// ioDiacritics ImGui demo — a cross-platform (Windows / macOS / Linux) window that restores
// Bosnian / Croatian / Serbian diacritics (č ć š ž đ) using the library's own C++17 port.
//
//   ošišana text  ->  dešišana text
//   Drzava takodje moze.  ->  Država takođe može.
//
// The engine is `iodiacritics::Restorer` from ../ioDiacritics/cpp. Auto-detect and the
// change-highlighting diff are demo-side, mirroring the Swift demo next door.

#include "imgui.h"
#include "imgui_impl_glfw.h"
#include "imgui_impl_opengl3.h"
#include "imgui_stdlib.h"

#include <GLFW/glfw3.h>

#include "iodiacritics/iodiacritics.hpp"

#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <optional>
#include <string>
#include <vector>

using iodiacritics::Restorer;
using iodiacritics::LangStats;

// ----------------------------------------------------------------------------------------
// Engine wrapper: the three language packs + auto-detect + diff.
// ----------------------------------------------------------------------------------------

enum class Lang { Auto = 0, Bosnian, Croatian, Serbian };

struct Pack {
    Restorer restorer;
    LangStats stats;
    bool loaded = false;
};

struct Engine {
    Pack bs, hr, sr;

    bool anyLoaded() const { return bs.loaded || hr.loaded || sr.loaded; }

    const Pack* pack(Lang l) const {
        switch (l) {
            case Lang::Bosnian:  return &bs;
            case Lang::Croatian: return &hr;
            case Lang::Serbian:  return &sr;
            default:             return nullptr;
        }
    }
};

// A run of the restored text. `word` = letters/digits (vs separator); `changed` = the
// restorer rewrote it from the input.
struct Run {
    std::string text;
    bool word;
    bool changed;
};

struct Outcome {
    std::string restored;
    Lang used = Lang::Serbian;   // the concrete pack that actually ran
    bool ambiguous = false;      // (auto mode) the BCS varieties couldn't be separated
    std::vector<Run> runs;
    int changedWords = 0;
};

// Result of auto-detection: the best concrete pack, plus whether the choice was actually
// distinguishable. BCS varieties share almost all šišana→restored mappings, so for most text
// the balanced signals tie and only the (size-skewed) invariant set differs — in that case we
// flag `ambiguous` and the UI honestly reports "Serbo-Croatian" rather than guessing.
struct Detection {
    Lang lang = Lang::Serbian;
    bool ambiguous = false;
};

// A char is a "word" char unless it is ASCII whitespace or ASCII punctuation. UTF-8 lead/
// continuation bytes (>= 0x80, i.e. accented letters) therefore stay inside words, so the
// same split lines up between the bald input and the accented output (the restorer only ever
// substitutes letters, never moves separators).
static bool isWordByte(unsigned char c) {
    if (c >= 0x80) return true;                 // multibyte (accented letter) → word
    if (c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\f' || c == '\v') return false;
    // ASCII punctuation ranges
    if ((c >= '!' && c <= '/') || (c >= ':' && c <= '@') ||
        (c >= '[' && c <= '`') || (c >= '{' && c <= '~')) return false;
    return true;                                // letters, digits
}

static std::vector<std::pair<std::string, bool>> splitRuns(const std::string& s) {
    std::vector<std::pair<std::string, bool>> out;
    std::string cur;
    bool curWord = false;
    bool have = false;
    for (unsigned char c : s) {
        bool w = isWordByte(c);
        if (!have || w == curWord) {
            cur.push_back((char)c);
            curWord = w;
            have = true;
        } else {
            out.emplace_back(cur, curWord);
            cur.assign(1, (char)c);
            curWord = w;
        }
    }
    if (have) out.emplace_back(cur, curWord);
    return out;
}

static std::vector<std::string> wordTokens(const std::string& s) {
    std::vector<std::string> words;
    for (auto& r : splitRuns(s)) if (r.second) words.push_back(r.first);
    return words;
}

// Auto-detect the BCS variety. Each pack is scored on three signals, in priority order:
//   1. edits     — confident restorations the pack would make (balanced across packs);
//   2. idxCov     — words present in the fixable reverse-index (balanced, ~115-157k each);
//   3. langCov    — words valid per is_language(), incl. the invariant set (size-skewed: the
//                   shipped Serbian invariant is far smaller, so this is only a last resort).
// `edits` and `idxCov` are the meaningful, comparable signals; if they fail to separate the
// winner from the runner-up, the text is genuinely indistinguishable between varieties and we
// mark the result ambiguous (the UI then says "Serbo-Croatian"). The chosen pack is still fine
// to restore with — tied packs produce near-identical output.
static Detection detect(const Engine& e, const std::string& text) {
    Detection out;
    auto words = wordTokens(text);
    if (words.empty()) return out;

    struct Cand { Lang lang; const Pack* p; long edits, idxCov, langCov; };
    Cand cands[] = {
        {Lang::Serbian, &e.sr, 0, 0, 0}, {Lang::Croatian, &e.hr, 0, 0, 0}, {Lang::Bosnian, &e.bs, 0, 0, 0},
    };

    for (auto& c : cands) {
        if (!c.p->loaded) continue;
        for (auto& w : words) {
            std::string lower = iodiacritics::lowercase_utf8(w);
            for (auto& k : c.p->restorer.profile().bald_keys(lower)) {
                if (c.p->restorer.index().count(k)) { ++c.idxCov; break; }
            }
            if (c.p->restorer.is_language(lower)) ++c.langCov;
            auto fixed = c.p->restorer.restore(w);
            if (fixed && *fixed != w) ++c.edits;
        }
    }

    const Cand* best = nullptr;
    for (auto& c : cands) {
        if (!c.p->loaded) continue;
        auto key = [](const Cand& x) { return std::make_tuple(x.edits, x.idxCov, x.langCov); };
        if (!best || key(c) > key(*best)) best = &c;
    }
    if (!best) return out;
    out.lang = best->lang;

    // Ambiguous if another loaded pack ties the winner on the *balanced* signals (edits, idxCov)
    // — i.e. the win came only from the skewed invariant count or arbitrary order.
    for (auto& c : cands) {
        if (!c.p->loaded || &c == best) continue;
        if (c.edits == best->edits && c.idxCov == best->idxCov) { out.ambiguous = true; break; }
    }
    return out;
}

static Outcome restore(const Engine& e, const std::string& text, Lang lang) {
    Outcome o;
    Lang resolved;
    if (lang == Lang::Auto) {
        Detection d = detect(e, text);
        resolved = d.lang;
        o.ambiguous = d.ambiguous;
    } else {
        resolved = lang;
    }
    const Pack* p = e.pack(resolved);
    o.used = resolved;
    if (!p || !p->loaded) {
        o.restored = text;
        if (!text.empty()) o.runs.push_back({text, false, false});
        return o;
    }
    o.restored = p->restorer.restore_prepared_text(text);

    auto a = splitRuns(text);
    auto b = splitRuns(o.restored);
    size_t n = std::min(a.size(), b.size());
    for (size_t i = 0; i < n; ++i) {
        bool changed = b[i].second && (a[i].first != b[i].first);
        if (changed) ++o.changedWords;
        o.runs.push_back({b[i].first, b[i].second, changed});
    }
    for (size_t i = n; i < b.size(); ++i) o.runs.push_back({b[i].first, b[i].second, false});
    return o;
}

// ----------------------------------------------------------------------------------------
// Dictionary loading — repo checkout via compile-time path / env / argv, with ./data fallback.
// ----------------------------------------------------------------------------------------

static bool fileExists(const std::string& path) {
    std::ifstream f(path);
    return f.good();
}

static std::optional<Restorer> tryLoad(const std::vector<std::string>& candidates,
                                       const iodiacritics::LanguageProfile& profile) {
    for (auto& path : candidates) {
        if (!fileExists(path)) continue;
        // load_invariant=true materialises the full diacritic-free word set (tens to hundreds
        // of thousands of entries per language). PolyType skips it to save RAM on a live
        // keyboard; this demo wants maximum quality, so it pays the memory for a proper
        // is_language() language anchor and better auto-detection.
        Restorer r = Restorer::load_file(path, profile, /*load_invariant=*/true);
        if (!r.index().empty()) return r;
    }
    return std::nullopt;
}

static void loadEngine(Engine& e, const std::string& repoRoot) {
    struct Spec {
        Pack* pack;
        iodiacritics::LanguageProfile profile;
        LangStats stats;
        std::string relSource;   // path inside the library checkout
        std::string dataName;    // bare filename for the ./data fallback
    };
    Spec specs[] = {
        {&e.bs, iodiacritics::bosnian_profile(),  iodiacritics::bosnian_stats(),
         "/Sources/ioDiacriticsBosnian/Resources/deshishana_bs.json",  "deshishana_bs.json"},
        {&e.hr, iodiacritics::croatian_profile(), iodiacritics::croatian_stats(),
         "/Sources/ioDiacriticsCroatian/Resources/deshishana_hr.json", "deshishana_hr.json"},
        {&e.sr, iodiacritics::serbian_profile(),  iodiacritics::serbian_stats(),
         "/Sources/ioDiacriticsSerbian/Resources/deshishana_sr.json",  "deshishana_sr.json"},
    };
    for (auto& s : specs) {
        std::vector<std::string> candidates = {
            repoRoot + s.relSource,
            "data/" + s.dataName,
            "./" + s.dataName,
        };
        if (auto r = tryLoad(candidates, s.profile)) {
            s.pack->restorer = std::move(*r);
            s.pack->stats = s.stats;
            s.pack->loaded = true;
        } else {
            std::fprintf(stderr, "warning: could not load %s\n", s.dataName.c_str());
        }
    }
}

// ----------------------------------------------------------------------------------------
// Rendering: word-wrapped, per-run colored text via the window draw list.
// ----------------------------------------------------------------------------------------

static void renderRuns(const std::vector<Run>& runs) {
    ImDrawList* dl = ImGui::GetWindowDrawList();
    ImFont* font = ImGui::GetFont();
    const float fontSize = ImGui::GetFontSize();
    const float lineH = ImGui::GetTextLineHeight();
    float wrapW = ImGui::GetContentRegionAvail().x;
    if (wrapW < 60.0f) wrapW = 60.0f;

    const ImVec2 origin = ImGui::GetCursorScreenPos();
    ImVec2 pos = origin;
    const ImU32 accent = IM_COL32(94, 167, 255, 255);
    const ImU32 normal = ImGui::GetColorU32(ImGuiCol_Text);

    auto newline = [&]() { pos.x = origin.x; pos.y += lineH; };
    auto draw = [&](const char* b, const char* e, ImU32 col) {
        if (b == e) return;
        float w = font->CalcTextSizeA(fontSize, FLT_MAX, 0.0f, b, e).x;
        if (pos.x > origin.x && pos.x + w > origin.x + wrapW) newline();
        dl->AddText(font, fontSize, pos, col, b, e);
        pos.x += w;
    };

    for (const auto& r : runs) {
        if (r.word) {
            draw(r.text.data(), r.text.data() + r.text.size(), r.changed ? accent : normal);
        } else {
            const char* p = r.text.data();
            const char* end = p + r.text.size();
            while (p < end) {
                if (*p == '\n') { newline(); ++p; continue; }
                const char* q = p;
                while (q < end && *q != '\n') ++q;
                draw(p, q, normal);
                p = q;
            }
        }
    }
    ImGui::Dummy(ImVec2(wrapW, (pos.y - origin.y) + lineH));
}

// ----------------------------------------------------------------------------------------
// UI helpers
// ----------------------------------------------------------------------------------------

static const char* langMenuLabel(Lang l) {
    switch (l) {
        case Lang::Auto:     return "Auto-detect";
        case Lang::Bosnian:  return "Bosnian";
        case Lang::Croatian: return "Croatian";
        case Lang::Serbian:  return "Serbian";
    }
    return "?";
}

// "Српски / Serbian" -> "Serbian" (compact Latin half for the chip).
static std::string latinHalf(const std::string& name) {
    auto slash = name.rfind('/');
    if (slash == std::string::npos) return name;
    std::string s = name.substr(slash + 1);
    size_t b = s.find_first_not_of(" \t");
    size_t e = s.find_last_not_of(" \t");
    if (b == std::string::npos) return name;
    return s.substr(b, e - b + 1);
}

static void glfwErrorCallback(int error, const char* desc) {
    std::fprintf(stderr, "GLFW error %d: %s\n", error, desc);
}

// Headless verification of the engine (restore / detect / diff) — no window. Mirrors the
// Swift demo's self-test. Run with `iodiacritics_demo --selftest`.
static int runSelfTest(const Engine& e) {
    int failures = 0;
    auto check = [&](const char* label, bool pass, const std::string& detail) {
        std::printf("%s  %s  —  %s\n", pass ? "PASS" : "FAIL", label, detail.c_str());
        if (!pass) ++failures;
    };
    if (!e.anyLoaded()) {
        std::printf("FAIL  dictionaries  —  none loaded\n");
        return 1;
    }
    auto sr = restore(e, "Drzava takodje moze.", Lang::Serbian);
    check("serbian restore", sr.restored == "Država takođe može.", sr.restored);

    auto hr = restore(e, "nasa drzava", Lang::Croatian);
    check("croatian restore", hr.restored == "naša država", hr.restored);

    auto bs = restore(e, "Drzava takodjer moze.", Lang::Bosnian);
    check("bosnian restore", bs.restored == "Država također može.", bs.restored);

    check("changed-word count", sr.changedWords == 3, std::to_string(sr.changedWords) + " changed");

    std::string rebuilt;
    for (auto& r : sr.runs) rebuilt += r.text;
    check("runs reconstruct text", rebuilt == sr.restored, rebuilt);

    auto autoOut = restore(e, "Drzava takodje moze.", Lang::Auto);
    check("auto resolves concrete", autoOut.used != Lang::Auto, langMenuLabel(autoOut.used));
    check("auto restores", autoOut.restored.find("ž") != std::string::npos, autoOut.restored);

    auto empty = restore(e, "", Lang::Auto);
    check("empty input safe", empty.restored.empty() && empty.changedWords == 0, "ok");

    auto clean = restore(e, "Država može.", Lang::Serbian);
    check("clean text unchanged", clean.changedWords == 0, clean.restored);

    // Auto-detect honesty: BCS varieties share the šišana→restored mappings, so the balanced
    // signals can't separate them — detection must flag this rather than guess a variety.
    auto detBcs = detect(e, "Drzava takodje moze. Nasa pjesma je lijepa.");
    check("bcs flagged ambiguous", detBcs.ambiguous, detBcs.ambiguous ? "ambiguous" : "claimed certainty");
    check("ambiguous still resolves a pack", detBcs.lang != Lang::Auto, langMenuLabel(detBcs.lang));
    // Output is still correct regardless of which tied pack ran.
    auto am = restore(e, "Drzava takodje moze.", Lang::Auto);
    check("ambiguous restores correctly", am.restored == "Država takođe može.", am.restored);

    std::printf(failures == 0 ? "\nALL PASSED\n" : "\n%d FAILURE(S)\n", failures);
    return failures == 0 ? 0 : 1;
}

int main(int argc, char** argv) {
    // --- args: optional repo-root path + optional --selftest flag ------------------------
    bool selfTest = false;
    std::string repoRoot;
    for (int i = 1; i < argc; ++i) {
        std::string a = argv[i];
        if (a == "--selftest") selfTest = true;
        else if (repoRoot.empty()) repoRoot = a;
    }
    if (repoRoot.empty()) {
        if (const char* env = std::getenv("IODIACRITICS_REPO_ROOT")) repoRoot = env;
        else repoRoot = IODIACRITICS_REPO_ROOT;
    }

    Engine engine;
    loadEngine(engine, repoRoot);

    if (selfTest) return runSelfTest(engine);

    // --- window + GL + ImGui -------------------------------------------------------------
    glfwSetErrorCallback(glfwErrorCallback);
    if (!glfwInit()) {
        std::fprintf(stderr, "fatal: glfwInit failed\n");
        return 1;
    }
    const char* glslVersion = "#version 150";
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 2);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
    glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE);

    GLFWwindow* window = glfwCreateWindow(920, 600, "ioDiacritics Demo", nullptr, nullptr);
    if (!window) {
        std::fprintf(stderr, "fatal: window creation failed\n");
        glfwTerminate();
        return 1;
    }
    glfwMakeContextCurrent(window);
    glfwSwapInterval(1);

    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGuiIO& io = ImGui::GetIO();
    io.IniFilename = nullptr;   // demo: no imgui.ini persistence

    // Font with Latin Extended-A (č ć š ž đ) + Cyrillic (the "Српски" passport names). The
    // default ImGui font is ASCII-only, so without this they would render as boxes.
    static const ImWchar ranges[] = { 0x0020, 0x017F, 0x0400, 0x04FF, 0 };
    ImFontConfig cfg;
    cfg.OversampleH = 2;
    cfg.OversampleV = 2;
    bool fontLoaded = false;
    for (const char* file : { "/Roboto-Medium.ttf", "/DroidSans.ttf" }) {
        std::string path = std::string(IMGUI_FONT_DIR) + file;
        if (fileExists(path) &&
            io.Fonts->AddFontFromFileTTF(path.c_str(), 18.0f, &cfg, ranges)) {
            fontLoaded = true;
            break;
        }
    }
    if (!fontLoaded) io.Fonts->AddFontDefault();   // ASCII fallback (accents will be boxes)

    ImGui::StyleColorsDark();
    ImGui::GetStyle().FrameRounding = 5.0f;
    ImGui::GetStyle().WindowRounding = 0.0f;

    ImGui_ImplGlfw_InitForOpenGL(window, true);
    ImGui_ImplOpenGL3_Init(glslVersion);

    // --- state ---------------------------------------------------------------------------
    std::string input = "Drzava takodje moze. Zelim da naucim nasu pjesmu i da je procitam svaki dan.";
    int langIndex = 0;   // 0 Auto, 1 BS, 2 HR, 3 SR
    const Lang langs[] = { Lang::Auto, Lang::Bosnian, Lang::Croatian, Lang::Serbian };

    // cache so we only re-run the engine when input / language changes
    std::string cachedInput;
    int cachedLang = -1;
    Outcome outcome;
    bool justCopied = false;
    double copiedAt = 0.0;

    while (!glfwWindowShouldClose(window)) {
        glfwPollEvents();

        Lang lang = langs[langIndex];
        if (input != cachedInput || langIndex != cachedLang) {
            outcome = restore(engine, input, lang);
            cachedInput = input;
            cachedLang = langIndex;
        }
        if (justCopied && glfwGetTime() - copiedAt > 1.4) justCopied = false;

        ImGui_ImplOpenGL3_NewFrame();
        ImGui_ImplGlfw_NewFrame();
        ImGui::NewFrame();

        // one full-window panel
        ImGui::SetNextWindowPos(ImVec2(0, 0));
        ImGui::SetNextWindowSize(io.DisplaySize);
        ImGuiWindowFlags flags = ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_NoResize |
                                 ImGuiWindowFlags_NoMove | ImGuiWindowFlags_NoCollapse |
                                 ImGuiWindowFlags_NoBringToFrontOnFocus;
        ImGui::Begin("root", nullptr, flags);

        // header
        ImGui::TextUnformatted("ioDiacritics");
        ImGui::SameLine();
        ImGui::TextDisabled("— restore č ć š ž đ in Bosnian / Croatian / Serbian");

        // controls
        ImGui::SetNextItemWidth(170);
        ImGui::Combo("##lang", &langIndex, "Auto-detect\0Bosnian\0Croatian\0Serbian\0");
        if (lang == Lang::Auto && engine.anyLoaded()) {
            ImGui::SameLine();
            if (outcome.ambiguous) {
                // The varieties were indistinguishable from this text — report honestly.
                ImGui::TextColored(ImVec4(0.37f, 0.65f, 1.0f, 1.0f), "  Detected: Serbo-Croatian (BCS)");
            } else {
                const Pack* p = engine.pack(outcome.used);
                std::string name = p ? latinHalf(p->stats.language) : langMenuLabel(outcome.used);
                ImGui::TextColored(ImVec4(0.37f, 0.65f, 1.0f, 1.0f), "  Detected: %s", name.c_str());
            }
        }
        if (!engine.anyLoaded()) {
            ImGui::SameLine();
            ImGui::TextColored(ImVec4(1.0f, 0.5f, 0.4f, 1.0f),
                "  no dictionaries found — pass the ioDiacritics repo path as argv[1]");
        }

        ImGui::Separator();

        const float footerH = ImGui::GetFrameHeightWithSpacing() + ImGui::GetTextLineHeightWithSpacing();
        const float panesH = ImGui::GetContentRegionAvail().y - footerH;
        const float halfW = (ImGui::GetContentRegionAvail().x - ImGui::GetStyle().ItemSpacing.x) * 0.5f;

        // input pane
        ImGui::BeginChild("inputPane", ImVec2(halfW, panesH), true);
        {
            ImGui::TextDisabled("Ošišana — paste / type here");
            ImGui::SameLine(ImGui::GetContentRegionAvail().x - 46);
            if (ImGui::SmallButton("Clear")) input.clear();
            ImGui::InputTextMultiline("##in", &input,
                ImVec2(-FLT_MIN, ImGui::GetContentRegionAvail().y));
        }
        ImGui::EndChild();

        ImGui::SameLine();

        // output pane
        ImGui::BeginChild("outputPane", ImVec2(0, panesH), true);
        {
            if (outcome.changedWords == 0)
                ImGui::TextDisabled("Restored");
            else
                ImGui::TextDisabled("Restored — %d word%s fixed", outcome.changedWords,
                                    outcome.changedWords == 1 ? "" : "s");
            ImGui::SameLine(ImGui::GetContentRegionAvail().x - 50);
            if (ImGui::SmallButton(justCopied ? "Copied" : "Copy")) {
                ImGui::SetClipboardText(outcome.restored.c_str());
                justCopied = true;
                copiedAt = glfwGetTime();
            }
            ImGui::BeginChild("outScroll", ImVec2(0, 0), false);
            renderRuns(outcome.runs);
            ImGui::EndChild();
        }
        ImGui::EndChild();

        // footer: reliability passport for the pack that ran + library version
        const Pack* used = engine.pack(outcome.used);
        if (used && used->loaded) {
            ImGui::TextDisabled("%s", used->stats.summary().c_str());
        } else {
            ImGui::TextDisabled(" ");
        }

        ImGui::End();

        ImGui::Render();
        int w, h;
        glfwGetFramebufferSize(window, &w, &h);
        glViewport(0, 0, w, h);
        glClearColor(0.10f, 0.11f, 0.12f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);
        ImGui_ImplOpenGL3_RenderDrawData(ImGui::GetDrawData());
        glfwSwapBuffers(window);
    }

    ImGui_ImplOpenGL3_Shutdown();
    ImGui_ImplGlfw_Shutdown();
    ImGui::DestroyContext();
    glfwDestroyWindow(window);
    glfwTerminate();
    return 0;
}
