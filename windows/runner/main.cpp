#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <string>

#include "flutter_window.h"
#include "utils.h"

namespace {

constexpr wchar_t kProtocolScheme[] = L"com.insalah.app";
constexpr wchar_t kProtocolDescription[] = L"URL:In Salah Protocol";

std::wstring GetExecutablePath() {
  wchar_t executable_path[MAX_PATH];
  const DWORD length = GetModuleFileNameW(nullptr, executable_path, MAX_PATH);
  if (length == 0 || length == MAX_PATH) {
    return L"";
  }

  return std::wstring(executable_path, length);
}

void SetRegistryStringValue(HKEY key,
                            const wchar_t* value_name,
                            const std::wstring& value) {
  RegSetValueExW(key, value_name, 0, REG_SZ,
                 reinterpret_cast<const BYTE*>(value.c_str()),
                 static_cast<DWORD>((value.size() + 1) * sizeof(wchar_t)));
}

void RegisterProtocolHandler() {
  const std::wstring executable_path = GetExecutablePath();
  if (executable_path.empty()) {
    return;
  }

  const std::wstring protocol_key_path =
      L"Software\\Classes\\" + std::wstring(kProtocolScheme);
  HKEY protocol_key = nullptr;
  if (RegCreateKeyExW(HKEY_CURRENT_USER, protocol_key_path.c_str(), 0, nullptr,
                      REG_OPTION_NON_VOLATILE, KEY_WRITE, nullptr,
                      &protocol_key, nullptr) != ERROR_SUCCESS) {
    return;
  }

  SetRegistryStringValue(protocol_key, nullptr, kProtocolDescription);
  SetRegistryStringValue(protocol_key, L"URL Protocol", L"");
  RegCloseKey(protocol_key);

  const std::wstring command_key_path =
      protocol_key_path + L"\\shell\\open\\command";
  HKEY command_key = nullptr;
  if (RegCreateKeyExW(HKEY_CURRENT_USER, command_key_path.c_str(), 0, nullptr,
                      REG_OPTION_NON_VOLATILE, KEY_WRITE, nullptr,
                      &command_key, nullptr) != ERROR_SUCCESS) {
    return;
  }

  SetRegistryStringValue(command_key, nullptr,
                         L'"' + executable_path + L'"' + L" \"%1\"");
  RegCloseKey(command_key);
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  RegisterProtocolHandler();

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"In Salah", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
