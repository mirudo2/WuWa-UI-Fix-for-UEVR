#include <Windows.h>
#include "uevr/Plugin.hpp"

using namespace uevr;

#define PLUGIN_LOG_ONCE(...) { \
    static bool logged = false; \
    if (!logged) { \
        logged = true; \
        API::get()->log_info(__VA_ARGS__); \
    } \
}

class win_screenshot_plugin : public uevr::Plugin {
public:
    const UEVR_PluginInitializeParam* pluginParams;
    const UEVR_VRData* vrData;

    win_screenshot_plugin() = default;

    void on_dllmain() override {}

    void on_initialize() override {
        pluginParams = API::get()->param();
        vrData = pluginParams->vr;
    }

    bool screenshot_now() {
        char nVal[256] = {};
        vrData->get_mod_value("VR_JoystickDeadzone", nVal, 255);
        return (strstr(nVal, "0.200005") != nullptr);
    }

    void on_xinput_get_state(uint32_t* retval, uint32_t user_index, XINPUT_STATE* state) override {
        
        if (screenshot_now()) {
            INPUT inputs[4] = {};

            inputs[0].type = INPUT_KEYBOARD;
            inputs[0].ki.wVk = VK_LWIN;

            inputs[1].type = INPUT_KEYBOARD;
            inputs[1].ki.wVk = VK_SNAPSHOT;

            inputs[2].type = INPUT_KEYBOARD;
            inputs[2].ki.wVk = VK_SNAPSHOT;
            inputs[2].ki.dwFlags = KEYEVENTF_KEYUP;

            inputs[3].type = INPUT_KEYBOARD;
            inputs[3].ki.wVk = VK_LWIN;
            inputs[3].ki.dwFlags = KEYEVENTF_KEYUP;

            SendInput(4, inputs, sizeof(INPUT));

            vrData->set_mod_value("VR_JoystickDeadzone", "0.200000");
        }

    }

};

std::unique_ptr<win_screenshot_plugin> g_plugin{ new win_screenshot_plugin() };
