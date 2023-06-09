{ fcitx }: { pkgs, ... }@inputs:
{
	config.i18n =
	{
		defaultLocale = "zh_CN.UTF-8";
		supportedLocales = ["zh_CN.UTF-8/UTF-8" "en_US.UTF-8/UTF-8" "C.UTF-8/UTF-8"];
	}
	//
	(
		if fcitx then
		{
			inputMethod =
			{
				enabled = "fcitx5";
				fcitx5.addons = with inputs.pkgs; [fcitx5-rime fcitx5-chinese-addons fcitx5-mozc];
			};
		}
		else {}
	);
}
