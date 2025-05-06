#include <Windows.h>
#include <memory>
#include <cmath>
#include <chrono>
#include "uevr/Plugin.hpp"

using namespace uevr;

class GamepadToMousePlugin : public Plugin {
public:
    const UEVR_PluginInitializeParam* pluginParams;
    const UEVR_VRData* vrData;

    GamepadToMousePlugin()
        : _frameCount(0), _fps(0), _lastFpsTime(std::chrono::high_resolution_clock::now())
    {}

    void on_dllmain() override {}

    void on_initialize() override {
        pluginParams = API::get()->param();
        vrData = pluginParams->vr;
    }

    void SendMouseInput(DWORD mouseFlag) {
        INPUT input = {};
        input.type = INPUT_MOUSE;
        input.mi.dwFlags = mouseFlag;
        SendInput(1, &input, sizeof(INPUT));
    }

    void SendKeyboardInput(WORD key, bool keyDown) {
        INPUT input = {};
        input.type = INPUT_KEYBOARD;
        input.ki.wVk = key;
        input.ki.dwFlags = keyDown ? 0 : KEYEVENTF_KEYUP;
        SendInput(1, &input, sizeof(INPUT));
    }

    void ClickAtCoordinate(int x, int y) {
        int sw = GetSystemMetrics(SM_CXSCREEN);
        int sh = GetSystemMetrics(SM_CYSCREEN);
        LONG ax = (x * 65535) / sw;
        LONG ay = (y * 65535) / sh;
        INPUT in[3] = {};
        in[0].type = INPUT_MOUSE;
        in[0].mi.dx = ax;
        in[0].mi.dy = ay;
        in[0].mi.dwFlags = MOUSEEVENTF_MOVE | MOUSEEVENTF_ABSOLUTE;
        in[1].type = INPUT_MOUSE;
        in[1].mi.dwFlags = MOUSEEVENTF_LEFTDOWN;
        in[2].type = INPUT_MOUSE;
        in[2].mi.dwFlags = MOUSEEVENTF_LEFTUP;
        SendInput(3, in, sizeof(INPUT));
    }

    bool isCursorVisible() {
        char buf[256] = {};
        vrData->get_mod_value("FrameworkConfig_AlwaysShowCursor", buf, 255);
        return strcmp(buf, "true") == 0;
    }

    bool lastButtonAState = false;

    void on_xinput_get_state(uint32_t* retval, uint32_t user_index, XINPUT_STATE* state) override {
        if (!state) return;

        _frameCount++;
        auto nowF = std::chrono::high_resolution_clock::now();
        std::chrono::duration<double> dtF = nowF - _lastFpsTime;
        if (dtF.count() >= 1.0) {
            _fps = _frameCount;
            _frameCount = 0;
            _lastFpsTime = nowF;
        }

        processRecentering(state);

        bool rt = (state->Gamepad.wButtons & XINPUT_GAMEPAD_RIGHT_THUMB) != 0;
        bool ls = (state->Gamepad.wButtons & XINPUT_GAMEPAD_LEFT_SHOULDER) != 0;

        processSpecialCombination(state);

        if (rt && ls) {
            state->Gamepad.sThumbRX = 0;
            state->Gamepad.sThumbRY = 0;
            state->Gamepad.wButtons &= ~(XINPUT_GAMEPAD_LEFT_SHOULDER | XINPUT_GAMEPAD_RIGHT_THUMB);
        }

        if (!isCursorVisible()) return;

        processMouseMovementAndScroll(state);
        processMouseClickForA(state);
        processDPADKeys(state);
        processButtonB(state);

        state->Gamepad.sThumbLX = 0;
        state->Gamepad.sThumbLY = 0;
        state->Gamepad.wButtons &= ~(XINPUT_GAMEPAD_A | XINPUT_GAMEPAD_X |
            XINPUT_GAMEPAD_DPAD_RIGHT | XINPUT_GAMEPAD_DPAD_LEFT |
            XINPUT_GAMEPAD_DPAD_UP | XINPUT_GAMEPAD_DPAD_DOWN);
    }

private:
    int _frameCount;
    int _fps;
    std::chrono::time_point<std::chrono::high_resolution_clock> _lastFpsTime;

    void processRecentering(const XINPUT_STATE* state) {
        bool lt = (state->Gamepad.wButtons & XINPUT_GAMEPAD_LEFT_THUMB) != 0;
        bool a = (state->Gamepad.wButtons & XINPUT_GAMEPAD_A) != 0;
        if (lt && a && !lastButtonAState) {
            vrData->recenter_view();
            vrData->recenter_horizon();
        }
        lastButtonAState = a;
    }

    void processKeyEvent(WORD gb, WORD key, bool& ls, const XINPUT_STATE* state) {
        bool cs = (state->Gamepad.wButtons & gb) != 0;
        if (cs && !ls) SendKeyboardInput(key, true);
        else if (!cs && ls) SendKeyboardInput(key, false);
        ls = cs;
    }

    void processMouseMovementAndScroll(const XINPUT_STATE* state) {
        int lx = state->Gamepad.sThumbLX;
        int ly = state->Gamepad.sThumbLY;
        const int DZ = 8000;
        if (abs(lx) < DZ) lx = 0;
        if (abs(ly) < DZ) ly = 0;

        float nlx = lx / 32767.0f;
        float nly = ly / 32767.0f;
        const float sensitivity = 1000.0f;
        float dt = _fps > 0 ? (1.0f / _fps) : 0.0f;
        float tvx = nlx * sensitivity * dt;
        float tvy = nly * sensitivity * dt;

        static float svx = 0.0f, svy = 0.0f;
        const float sf = 0.1f;
        svx += (tvx - svx) * sf;
        svy += (tvy - svy) * sf;

        static float ax = 0.0f, ay = 0.0f;
        ax += svx;
        ay += svy;
        int mx = int(ax), my = int(ay);
        ax -= mx;
        ay -= my;

        bool xp = (state->Gamepad.wButtons & XINPUT_GAMEPAD_X) != 0;
        if (!xp) {
            if (mx || my) {
                INPUT im = {};
                im.type = INPUT_MOUSE;
                im.mi.dwFlags = MOUSEEVENTF_MOVE;
                im.mi.dx = mx;
                im.mi.dy = -my;
                SendInput(1, &im, sizeof(INPUT));
            }
        }
        else {
            static auto lst = std::chrono::steady_clock::now();
            static float sac = 0.0f;
            auto now = std::chrono::steady_clock::now();
            float dt2 = std::chrono::duration<float>(now - lst).count();
            lst = now;
            if (ly == 0) { sac = 0.0f; return; }
            float em = (abs(ly) - DZ) / float(32767 - DZ);
            em = ly > 0 ? em : -em;
            const float ss = 2500.0f;
            sac += em * ss * dt2;
            if (abs(sac) >= 1.0f) {
                int sa = int(sac);
                sac -= sa;
                INPUT is = {};
                is.type = INPUT_MOUSE;
                is.mi.dwFlags = MOUSEEVENTF_WHEEL;
                is.mi.mouseData = sa;
                SendInput(1, &is, sizeof(INPUT));
            }
        }
    }

    void processMouseClickForA(const XINPUT_STATE* state) {
        static bool la = false;
        bool ca = (state->Gamepad.wButtons & XINPUT_GAMEPAD_A) != 0;
        if (ca && !la) SendMouseInput(MOUSEEVENTF_LEFTDOWN);
        else if (!ca && la) SendMouseInput(MOUSEEVENTF_LEFTUP);
        la = ca;
    }

    void processDPADKeys(const XINPUT_STATE* state) {
        static bool lu = false, ll = false, ld = false, lr = false;
        processKeyEvent(XINPUT_GAMEPAD_DPAD_UP, 'W', lu, state);
        processKeyEvent(XINPUT_GAMEPAD_DPAD_LEFT, 'A', ll, state);
        processKeyEvent(XINPUT_GAMEPAD_DPAD_DOWN, 'S', ld, state);
        processKeyEvent(XINPUT_GAMEPAD_DPAD_RIGHT, 'D', lr, state);
    }

    void processButtonB(const XINPUT_STATE* state) {
        static bool lb = false;
        bool cb = (state->Gamepad.wButtons & XINPUT_GAMEPAD_B) != 0;
        if (cb && !lb) {
            int sw = GetSystemMetrics(SM_CXSCREEN);
            ClickAtCoordinate(sw / 2 + 800, 70);
        }
        lb = cb;
    }

    void processSpecialCombination(const XINPUT_STATE* state) {
        bool rt = (state->Gamepad.wButtons & XINPUT_GAMEPAD_RIGHT_THUMB) != 0;
        bool ls = (state->Gamepad.wButtons & XINPUT_GAMEPAD_LEFT_SHOULDER) != 0;
        static bool lc = false, ts = false;
        static auto st = std::chrono::steady_clock::now();
        bool cc = rt && ls;
        if (cc && !lc) {
            st = std::chrono::steady_clock::now();
            ts = false;
            int sw = GetSystemMetrics(SM_CXSCREEN);
            int sh = GetSystemMetrics(SM_CYSCREEN);
            ClickAtCoordinate(sw / 2, sh / 2);
            Sleep(30);
            SendKeyboardInput('V', true);
            SendKeyboardInput('V', false);
        }
        if (cc && !ts) {
            if (std::chrono::steady_clock::now() - st >= std::chrono::milliseconds(800)) {
                SendKeyboardInput(VK_TAB, true);
                ts = true;
            }
        }
        else if (!cc && lc) {
            if (ts) SendKeyboardInput(VK_TAB, false);
        }
        lc = cc;
    }
};

std::unique_ptr<GamepadToMousePlugin> g_plugin{ new GamepadToMousePlugin() };
