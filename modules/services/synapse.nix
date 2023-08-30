inputs:
{
	options.nixos.services = let inherit (inputs.lib) mkOption types; in
	{
		synapse =
		{
			enable = mkOption { type = types.bool; default = false; };
			port = mkOption { type = types.ints.unsigned; default = 8008; };
			hostname = mkOption { type = types.str; default = "synapse.chn.moe"; };
		};
		synapse-proxy = mkOption
		{
			type = types.attrsOf (types.submodule (submoduleInputs: { options =
			{
				hostname = mkOption { type = types.str; default = submoduleInputs.config._module.args.name; };
			};}));
			default = {};
		};
	};
	config =
		let
			inherit (inputs.config.nixos.services) synapse synapse-proxy;
			inherit (inputs.localLib) attrsToList;
			inherit (inputs.lib) mkIf mkMerge;
			inherit (builtins) map listToAttrs;
		in mkMerge
		[
			(mkIf synapse.enable
			{
				services.matrix-synapse =
				{
					enable = true;
					settings =
					{
						server_name = synapse.hostname;
						listeners =
						[{
							bind_addresses = [ "127.0.0.1" ];
							port = 8008;
							resources = [{ names = [ "client" "federation" ]; compress = false; }];
							tls = false;
							type = "http";
							x_forwarded = true;
						}];
						database =
						{
							name = "psycopg2";
							args =
							{
								user = "synapse";
								database = "synapse";
								host = "127.0.0.1";
								port = "5432";
							};
						};
						admin_contact = "mailto:chn@chn.moe";
						enable_registration = true;
						registrations_require_3pid = [ "email" ];
						turn_uris = [ "turn:coturn.chn.moe" ];
						max_upload_size = "1024M";
						web_client_location = "https://element.chn.moe/";
						serve_server_wellknown = true;
						report_stats = true;
						trusted_key_servers = [{ server_name = "matrix.org"; }];
						suppress_key_server_warning = true;
						log_config = (inputs.pkgs.formats.yaml {}).generate "log.yaml"
						{
							version = 1;
							formatters.precise.format =
								"%(asctime)s - %(name)s - %(lineno)d - %(levelname)s - %(request)s - %(message)s";
							handlers.console = { class = "logging.StreamHandler"; formatter = "precise"; };
							root = { level = "INFO"; handlers = [ "console" ]; };
							disable_existing_loggers = true;
						};
					};
					extraConfigFiles = [ inputs.config.sops.templates."synapse/password.yaml".path ];
				};
				sops =
				{
					templates."synapse/password.yaml" =
					{
						owner = inputs.config.systemd.services.matrix-synapse.serviceConfig.User;
						group = inputs.config.systemd.services.matrix-synapse.serviceConfig.Group;
						content = builtins.readFile ((inputs.pkgs.formats.yaml {}).generate "password.yaml"
						{
							database =
							{
								name = "psycopg2";
								args =
								{
									user = "synapse";
									password = inputs.config.sops.placeholder."postgresql/synapse";
									database = "synapse";
									host = "127.0.0.1";
									port = "5432";
								};
								allow_unsafe_locale = true;
							};
							turn_shared_secret = inputs.config.sops.placeholder."synapse/coturn";
							registration_shared_secret = inputs.config.sops.placeholder."synapse/registration";
							macaroon_secret_key = inputs.config.sops.placeholder."synapse/macaroon";
							form_secret = inputs.config.sops.placeholder."synapse/form";
							signing_key_path = inputs.config.sops.secrets."synapse/signing-key".path;
							email =
							{
								smtp_host = "mail.chn.moe";
								smtp_port = 25;
								smtp_user = "bot@chn.moe";
								smtp_pass = inputs.config.sops.placeholder."mail/bot";
								require_transport_security = true;
								notif_from = "Your Friendly %(app)s homeserver <bot@chn.moe>";
								app_name = "Haonan Chen's synapse";
							};
						});
					};
					secrets = (listToAttrs (map
						(secret: { name = "synapse/${secret}"; value = {}; })
						[ "coturn" "registration" "macaroon" "form" ]))
						// { "synapse/signing-key".owner = inputs.config.systemd.services.matrix-synapse.serviceConfig.User; }
						// { "mail/bot" = {}; };
				};
				nixos.services =
				{
					nginx =
					{
						enable = true;
						httpProxy =
						{
							"${synapse.hostname}" =
							{
								upstream = "http://127.0.0.1:${toString synapse.port}";
								websocket = true;
								setHeaders.Host = synapse.hostname;
							};
							"direct.${synapse.hostname}" =
							{
								upstream = "http://127.0.0.1:${toString synapse.port}";
								websocket = true;
								setHeaders.Host = synapse.hostname;
								detectAuth = true;
							};
						};
					};
					postgresql = { enable = true; instances.synapse = {}; };
				};
			})
			(mkIf (synapse-proxy != {})
			{
				nixos.services.nginx =
				{
					enable = true;
					httpProxy = listToAttrs (map
						(proxy:
						{
							name = proxy.value.hostname;
							value =
							{
								upstream = "https://direct.${proxy.value.hostname}";
								websocket = true;
								setHeaders.Host = "direct.${proxy.value.hostname}";
								addAuth = true;
							};
						})
						(attrsToList synapse-proxy));
				};
			})
		];
}
