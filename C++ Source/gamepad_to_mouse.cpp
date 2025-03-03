#include <Windows.h>
#include <memory>
#include <cmath>
#include <chrono>
#include "uevr/Plugin.hpp"

using namespace uevr;

#define PLUGIN_LOG_ONCE(...) { \
    static bool logged = false; \
    if (!logged) { \
        logged = true; \
        API::get()->log_info(__VA_ARGS__); \
    } \
}

class GamepadToMousePlugin : public uevr::Plugin {
public:
    const UEVR_PluginInitializeParam* pluginParams;
    const UEVR_VRData* vrData;

    GamepadToMousePlugin() = default;

    void on_dllmain() override {}

    void on_initialize() override {
        pluginParams = API::get()->param();
        vrData = pluginParams->vr;
    }

    // Sends a mouse input event with the specified flag.
    void SendMouseInput(DWORD mouseFlag) {
        INPUT input = {};
        input.type = INPUT_MOUSE;
        input.mi.dwFlags = mouseFlag;
        SendInput(1, &input, sizeof(INPUT));
    }

    // Sends a keyboard input event for the given key.
    void SendKeyboardInput(WORD key, bool keyDown) {
        INPUT input = {};
        input.type = INPUT_KEYBOARD;
        input.ki.wVk = key;
        input.ki.dwFlags = keyDown ? 0 : KEYEVENTF_KEYUP;
        SendInput(1, &input, sizeof(INPUT));
    }

    // Clicks at a specific screen coordinate.
    void ClickAtCoordinate(int x, int y) {
        int screenWidth = GetSystemMetrics(SM_CXSCREEN);
        int screenHeight = GetSystemMetrics(SM_CYSCREEN);
        LONG absX = (x * 65535) / screenWidth;
        LONG absY = (y * 65535) / screenHeight;

        INPUT inputs[3] = {};

        // Move mouse to coordinate.
        inputs[0].type = INPUT_MOUSE;
        inputs[0].mi.dx = absX;
        inputs[0].mi.dy = absY;
        inputs[0].mi.dwFlags = MOUSEEVENTF_MOVE | MOUSEEVENTF_ABSOLUTE;

        // Left mouse button down.
        inputs[1].type = INPUT_MOUSE;
        inputs[1].mi.dwFlags = MOUSEEVENTF_LEFTDOWN;

        // Left mouse button up.
        inputs[2].type = INPUT_MOUSE;
        inputs[2].mi.dwFlags = MOUSEEVENTF_LEFTUP;

        SendInput(3, inputs, sizeof(INPUT));
    }

    // Returns true if the cursor should be visible.
    bool isCursorVisible() {
        char showCursor[256] = {};
        vrData->get_mod_value("FrameworkConfig_AlwaysShowCursor", showCursor, 255);
        return (strcmp(showCursor, "true") == 0);
    }

    // Tracks the previous state of button A for recentering.
    bool lastButtonAState = false;

    // XInput state callback.
    void on_xinput_get_state(uint32_t* retval, uint32_t user_index, XINPUT_STATE* state) override {
        if (!state)
            return;

        processRecentering(state);

        bool rightThumbPressed = (state->Gamepad.wButtons & XINPUT_GAMEPAD_RIGHT_THUMB) != 0;
        bool leftShoulderPressed = (state->Gamepad.wButtons & XINPUT_GAMEPAD_LEFT_SHOULDER) != 0;

        processSpecialCombination(state);

        if (rightThumbPressed && leftShoulderPressed) {

            state->Gamepad.sThumbRX = 0;
            state->Gamepad.sThumbRY = 0;

            state->Gamepad.wButtons &= ~(XINPUT_GAMEPAD_LEFT_SHOULDER | XINPUT_GAMEPAD_RIGHT_THUMB);

        }

        if (!isCursorVisible())
            return;

        processMouseMovementAndScroll(state);
        processMouseClickForA(state);
        processDPADKeys(state);
        processButtonB(state);

        // Clear thumbstick and directional button inputs.
        state->Gamepad.sThumbLX = 0;
        state->Gamepad.sThumbLY = 0;

        state->Gamepad.wButtons &= ~(XINPUT_GAMEPAD_A | XINPUT_GAMEPAD_X |
            XINPUT_GAMEPAD_DPAD_RIGHT | XINPUT_GAMEPAD_DPAD_LEFT |
            XINPUT_GAMEPAD_DPAD_UP | XINPUT_GAMEPAD_DPAD_DOWN);

    }

private:
    // Recenter view/horizon when left thumb and A are pressed.
    void processRecentering(const XINPUT_STATE* state) {
        bool leftThumbPressed = (state->Gamepad.wButtons & XINPUT_GAMEPAD_LEFT_THUMB) != 0;
        bool buttonAPressed = (state->Gamepad.wButtons & XINPUT_GAMEPAD_A) != 0;
        if (leftThumbPressed && buttonAPressed && !lastButtonAState) {
            vrData->recenter_view();
            vrData->recenter_horizon();
        }
        lastButtonAState = buttonAPressed;
    }

    // Helper to process keyboard events.
    void processKeyEvent(WORD gamepadButton, WORD key, bool& lastState, const XINPUT_STATE* state) {
        bool currentState = (state->Gamepad.wButtons & gamepadButton) != 0;
        if (currentState && !lastState)
            SendKeyboardInput(key, true);
        else if (!currentState && lastState)
            SendKeyboardInput(key, false);
        lastState = currentState;
    }

    // Process mouse movement and scrolling based on thumbstick input.
    void processMouseMovementAndScroll(const XINPUT_STATE* state) {
        int thumbLX = state->Gamepad.sThumbLX;
        int thumbLY = state->Gamepad.sThumbLY;
        const int DEADZONE = 8000;
        if (std::abs(thumbLX) < DEADZONE)
            thumbLX = 0;
        if (std::abs(thumbLY) < DEADZONE)
            thumbLY = 0;

        // Process mouse movement.
        float normLX = thumbLX / 32767.0f;
        float normLY = thumbLY / 32767.0f;
        const float sensitivity = 18.0f;
        float targetVelX = normLX * sensitivity;
        float targetVelY = normLY * sensitivity;

        static float smoothedVelX = 0.0f;
        static float smoothedVelY = 0.0f;
        const float smoothingFactor = 0.1f;
        smoothedVelX += (targetVelX - smoothedVelX) * smoothingFactor;
        smoothedVelY += (targetVelY - smoothedVelY) * smoothingFactor;

        static float accumulatedX = 0.0f;
        static float accumulatedY = 0.0f;
        accumulatedX += smoothedVelX;
        accumulatedY += smoothedVelY;

        int moveX = static_cast<int>(accumulatedX);
        int moveY = static_cast<int>(accumulatedY);
        accumulatedX -= moveX;
        accumulatedY -= moveY;

        bool buttonXPressed = (state->Gamepad.wButtons & XINPUT_GAMEPAD_X) != 0;
        if (!buttonXPressed) {
            // Mouse movement.
            if (moveX != 0 || moveY != 0) {
                INPUT inputMove = {};
                inputMove.type = INPUT_MOUSE;
                inputMove.mi.dwFlags = MOUSEEVENTF_MOVE;
                inputMove.mi.dx = moveX;
                inputMove.mi.dy = -moveY; // Invert Y if needed.
                SendInput(1, &inputMove, sizeof(INPUT));
            }
        }
        else {
            // Smooth scrolling using vertical thumbstick movement.
            static auto lastScrollTime = std::chrono::steady_clock::now();
            static float scrollAccumulator = 0.0f;

            auto now = std::chrono::steady_clock::now();
            float deltaTime = std::chrono::duration<float>(now - lastScrollTime).count();
            lastScrollTime = now;

            // Reset accumulator if thumbLY is zero.
            if (thumbLY == 0) {
                scrollAccumulator = 0.0f;
                return;
            }

            // Remap thumbLY to an effective scroll magnitude.
            float effectiveMagnitude = (std::abs(thumbLY) - DEADZONE) / (32767.0f - DEADZONE);
            effectiveMagnitude = (thumbLY > 0) ? effectiveMagnitude : -effectiveMagnitude;

            const float scrollSensitivity = 2500.0f; // Adjust sensitivity as needed.
            scrollAccumulator += effectiveMagnitude * scrollSensitivity * deltaTime;

            if (std::abs(scrollAccumulator) >= 1.0f) {
                int scrollAmount = static_cast<int>(scrollAccumulator);
                scrollAccumulator -= scrollAmount;

                INPUT inputScroll = {};
                inputScroll.type = INPUT_MOUSE;
                inputScroll.mi.dwFlags = MOUSEEVENTF_WHEEL;
                inputScroll.mi.mouseData = scrollAmount;
                SendInput(1, &inputScroll, sizeof(INPUT));
            }
        }
    }

    // Process left mouse click via A button (ignored when left thumb is pressed).
    void processMouseClickForA(const XINPUT_STATE* state) {
        if (!(state->Gamepad.wButtons & XINPUT_GAMEPAD_LEFT_THUMB)) {
            static bool lastAState = false;
            bool currentAState = (state->Gamepad.wButtons & XINPUT_GAMEPAD_A) != 0;
            if (currentAState && !lastAState)
                SendMouseInput(MOUSEEVENTF_LEFTDOWN);
            else if (!currentAState && lastAState)
                SendMouseInput(MOUSEEVENTF_LEFTUP);
            lastAState = currentAState;
        }
    }

    // Process DPAD keys mapping to keyboard (W, A, S, D).
    void processDPADKeys(const XINPUT_STATE* state) {
        static bool lastDpadUp = false;
        static bool lastDpadLeft = false;
        static bool lastDpadDown = false;
        static bool lastDpadRight = false;

        processKeyEvent(XINPUT_GAMEPAD_DPAD_UP, 'W', lastDpadUp, state);
        processKeyEvent(XINPUT_GAMEPAD_DPAD_LEFT, 'A', lastDpadLeft, state);
        processKeyEvent(XINPUT_GAMEPAD_DPAD_DOWN, 'S', lastDpadDown, state);
        processKeyEvent(XINPUT_GAMEPAD_DPAD_RIGHT, 'D', lastDpadRight, state);
    }

    // Process the B button to trigger a click at a specific coordinate.
    void processButtonB(const XINPUT_STATE* state) {
        static bool lastBState = false;
        bool currentBState = (state->Gamepad.wButtons & XINPUT_GAMEPAD_B) != 0;
        if (currentBState && !lastBState) {
            int screenWidth = GetSystemMetrics(SM_CXSCREEN);
            int closeBtnX = (screenWidth / 2) + 860;
            int targetY = 70;
            ClickAtCoordinate(closeBtnX, targetY);
        }
        lastBState = currentBState;
    }

    // Process a special combination (right thumb + left shoulder) to simulate a Tab action.
    void processSpecialCombination(const XINPUT_STATE* state) {
        bool rightThumbPressed = (state->Gamepad.wButtons & XINPUT_GAMEPAD_RIGHT_THUMB) != 0;
        bool leftShoulderPressed = (state->Gamepad.wButtons & XINPUT_GAMEPAD_LEFT_SHOULDER) != 0;
        static bool lastCombination = false;
        static bool tabActionSent = false;
        static auto combinationStartTime = std::chrono::steady_clock::now();

        bool currentCombination = rightThumbPressed && leftShoulderPressed;

        if (currentCombination && !lastCombination) {
            // Combination just started.
            combinationStartTime = std::chrono::steady_clock::now();
            tabActionSent = false;

            int screenWidth = GetSystemMetrics(SM_CXSCREEN);
            int screenHeight = GetSystemMetrics(SM_CYSCREEN);
            ClickAtCoordinate(screenWidth / 2, screenHeight / 2);

            Sleep(30);
            SendKeyboardInput('V', true);
            SendKeyboardInput('V', false);
        }

        if (currentCombination && !tabActionSent) {
            auto now = std::chrono::steady_clock::now();
            if (now - combinationStartTime >= std::chrono::milliseconds(800)) {
                SendKeyboardInput(VK_TAB, true);
                tabActionSent = true;
            }
        }
        else if (!currentCombination && lastCombination) {
            if (tabActionSent) {
                SendKeyboardInput(VK_TAB, false);
            }
        }

        lastCombination = currentCombination;
    }

};

std::unique_ptr<GamepadToMousePlugin> g_plugin{ new GamepadToMousePlugin() };
