{
	enable = true;
	shortcuts =
	{
		"ksmserver" = { "Lock Session" = ["Meta+L" "Screensaver"]; "Log Out" = "Ctrl+Alt+Del"; };
		"kwin" =
		{
			"Show Desktop" = "Meta+D";
			"Suspend Compositing" = "Alt+Shift+F12";
			"Walk Through Windows" = "Alt+Tab";
			"Walk Through Windows (Reverse)" = "Alt+Shift+Backtab";
			"Window Close" = "Alt+F4";
			"Window Maximize" = "Meta+PgUp";
			"Window Minimize" = "Meta+PgDown";
			"Window Quick Tile Bottom" = "Meta+Down";
			"Window Quick Tile Bottom Left" = "Meta+Down+Left";
			"Window Quick Tile Bottom Right" = "Meta+Down+Right";
			"Window Quick Tile Left" = "Meta+Left";
			"Window Quick Tile Right" = "Meta+Right";
			"Window Quick Tile Top" = "Meta+Up";
			"Window Quick Tile Top Left" = "Meta+Up+Left";
			"Window Quick Tile Top Right" = "Meta+Up+Right";
			"view_actual_size" = "Meta+0";
			"view_zoom_in" = ["Meta++" "Meta+="];
			"view_zoom_out" = "Meta+-";
		};
		# "mediacontrol"."playpausemedia" = "Media Play";
		"org.kde.dolphin.desktop"."_launch" = "Meta+E";
		"org.kde.konsole.desktop"."_launch" = "Ctrl+Alt+T";
		"org.kde.krunner.desktop"."_launch" = "Alt+Space";
		"org.kde.spectacle.desktop" =
		{
			"ActiveWindowScreenShot" = "Meta+Print";
			"CurrentMonitorScreenShot" = [ ];
			"FullScreenScreenShot" = "Shift+Print";
			"OpenWithoutScreenshot" = [ ];
			"RectangularRegionScreenShot" = "Meta+Shift+Print";
			"WindowUnderCursorScreenShot" = "Meta+Ctrl+Print";
			"_launch" = "Print";
		};
		"org_kde_powerdevil" =
		{
			"Decrease Screen Brightness" = "Monitor Brightness Down";
			"Increase Screen Brightness" = "Monitor Brightness Up";
		};
		"plasmashell" =
		{
			"next activity" = "Meta+Tab";
			"previous activity" = "Meta+Shift+Tab";
		};
		"yakuake"."toggle-window-state" = "Meta+Space";
	};
    files =
	{
		"baloofilerc"."Basic Settings"."Indexing-Enabled" = false;
		"kcminputrc"."Libinput.2321.21128.HTIX5288:00 0911:5288 Touchpad" =
			{ "ClickMethod" = 2; "MiddleButtonEmulation" = true; "TapToClick" = true; };
		"kded5rc" =
		{
			"Module-browserintegrationreminder"."autoload" = true;
			"Module-device_automounter"."autoload" = false;
		};
		"kdeglobals" =
		{
			"General"."BrowserApplication" = "firefox.desktop";
			"KDE"."widgetStyle" = "kvantum";
			"KFileDialog Settings" =
			{
				"Allow Expansion" = true;
				"Automatically select filename extension" = true;
				"Breadcrumb Navigation" = true;
				"Decoration position" = 2;
				"LocationCombo Completionmode" = 5;
				"PathCombo Completionmode" = 5;
				"Show Bookmarks" = true;
				"Show Full Path" = true;
				"Show Inline Previews" = true;
				"Show Preview" = true;
				"Show Speedbar" = true;
				"Show hidden files" = true;
				"Sort by" = "Name";
				"Sort directories first" = true;
				"Sort hidden files last" = false;
				"Sort reversed" = false;
				"Speedbar Width" = 89;
				"View Style" = "DetailTree";
			};
		};
		"kiorc"."Confirmations" = { "ConfirmDelete" = true; "ConfirmEmptyTrash" = true; };
		"krunnerrc" = {"General"."FreeFloating" = true; "Plugins"."baloosearchEnabled" = false; };
		"kscreenlockerrc"."Daemon"."Autolock" = false;
		"ksmserverrc"."General"."loginMode" = "emptySession";
		"kwalletrc"."Wallet"."First Use" = false;
		"kwinrc" =
		{
			"Effect-blur"."BlurStrength" = 10;
			"Effect-kwin4_effect_translucency"."MoveResize" = 75;
			"Effect-wobblywindows" = { "Drag" = 85; "ResizeWobble" = false; "Stiffness" = 10; "WobblynessLevel" = 1; };
			"Plugins" =
			{
				"blurEnabled" = true;
				"kwin4_effect_dimscreenEnabled" = true;
				"kwin4_effect_translucencyEnabled" = true;
				"slidebackEnabled" = true;
				"wobblywindowsEnabled" = true;
				"padding" = 4;
			};
			"Xwayland"."Scale" = 1;
		};
		"kxkbrc"."Layout" = { "LayoutList" = "us"; "Use" = true; "VariantList" = ""; };
		"plasma-localerc" = { "Formats"."LANG" = "en_US.UTF-8"; "Translations"."LANGUAGE" = "zh_CN"; };
		"plasmanotifyrc"."Notifications"."PopupPosition" = "BottomRight";
		"plasmarc"."Wallpapers"."usersWallpapers" = "/home/chn/Desktop/.桌面/twin_96734339_x2.png,/home/chn/Desktop/.桌面/E_yCTfDUUAgykjX_x8.jpeg";
	};
}
