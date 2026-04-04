{ ... }:
{
  flake.homeModules.browsers =
    { pkgs, ... }:
    {
      programs.chromium = {
        enable = true;
        package = pkgs.brave;
        commandLineArgs = [ "--password-store=basic" ];
        extensions = [
          { id = "dbepggeogbaibhgnhhndojpepiihcmeb"; }
        ];
      };

      programs.qutebrowser = {
        enable = true;

        loadAutoconfig = false;

        keyBindings = {
          normal = {
            P = "hint links run :open -p {hint-url}";
            d = null;
            D = null;
          };
        };

        extraConfig = ''
          # Per-domain content settings
          config.set('content.cookies.accept', 'all', 'chrome-devtools://*')
          config.set('content.cookies.accept', 'all', 'devtools://*')

          config.set('content.headers.user_agent', 'Mozilla/5.0 ({os_info}) AppleWebKit/{webkit_version} (KHTML, like Gecko) {upstream_browser_key}/{upstream_browser_version} Safari/{webkit_version}', 'https://web.whatsapp.com/')
          config.set('content.headers.user_agent', 'Mozilla/5.0 ({os_info}; rv:90.0) Gecko/20100101 Firefox/90.0', 'https://accounts.google.com/*')
          config.set('content.headers.user_agent', 'Mozilla/5.0 ({os_info}) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/99 Safari/537.36', 'https://*.slack.com/*')

          config.set('content.images', True, 'chrome-devtools://*')
          config.set('content.images', True, 'devtools://*')

          config.set('content.javascript.enabled', True, 'chrome-devtools://*')
          config.set('content.javascript.enabled', True, 'devtools://*')
          config.set('content.javascript.enabled', True, 'chrome://*/*')
          config.set('content.javascript.enabled', True, 'qute://*/*')

          c.fileselect.handler = 'external'
          c.fileselect.single_file.command = ['${pkgs.zenity}/bin/zenity', '--file-selection']
          c.fileselect.folder.command = ['${pkgs.zenity}/bin/zenity', '--file-selection', '--directory']
          c.fileselect.multiple_files.command = ['sh', '-c', '${pkgs.zenity}/bin/zenity --file-selection --multiple | tr "|" "\\n"']
        '';

        aliases = {
          w = "session-save";
          q = "close";
          qa = "quit";
          wq = "quit --save";
          wqa = "quit --save";
          Wq = "quit --save";
          WQ = "quit --save";
          wQ = "quit --save";
        };

        settings = {
          content = {
            autoplay = false;
            images = true;
            cookies.accept = "all";
            javascript.enabled = true;
            headers.accept_language = "";
            headers.user_agent = "Mozilla/5.0 ({os_info}) AppleWebKit/{webkit_version} (KHTML, like Gecko) {upstream_browser_key}/{upstream_browser_version} Safari/{webkit_version}";
          };

          tabs = {
            last_close = "close";
            position = "bottom";
            show = "switching";
            show_switching_delay = 2000;
          };

          url = {
            default_page = "https://search.brave.com";
            incdec_segments = [
              "path"
              "query"
            ];
            start_pages = "https://search.brave.com";
          };

          colors = {
            webpage = {
              preferred_color_scheme = "dark";
            };

            hints = {
              fg = "chartreuse";
              bg = "qlineargradient(x1:0, y1:0, x2:0, y2:1, stop:0 rgba(255, 0, 0, 0.8), stop:1 rgba(255, 0, 0, 0.8))";
            };
          };
        };

        searchEngines = {
          DEFAULT = "https://search.brave.com/search?q={}&source=web";
        };

        quickmarks = { };
      };
    };
}
