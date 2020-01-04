let
  packages = {
    pass-arc = { pass, pass-extension-meta, pass-extension-arc-b2, hostPlatform }: let
      pass-wrapped = pass.withExtensions (ext: [
        ext.pass-otp
        pass-extension-meta
        pass-extension-arc-b2
      ]);
    in pass-wrapped.overrideAttrs (old: {
      doInstallCheck = !hostPlatform.isDarwin;
    });

    nix-readline = { nix, readline, fetchurl, lib }: nix.overrideAttrs (old: {
      buildInputs = old.buildInputs ++ [ readline ];
      patches = old.patches or [] ++ lib.optional (lib.versionAtLeast lib.version "19.09") (fetchurl {
        name = "readline-completion.patch";
        url = "https://github.com/arcnmx/nix/commit/f4d1453c2b86aa576f1a707d47eb2174fd7e4a90.patch";
        sha256 = "18b3bv0wjkx5hmrmhbzf6rl6swcx8ibk29c5pk4fysjd71rfd5d0";
      });
      EDITLINE_LIBS = "${readline}/lib/libreadline${nix.stdenv.hostPlatform.extensions.sharedLibrary}";
      EDITLINE_CFLAGS = "-DREADLINE";
      doInstallCheck = old.doInstallCheck or false && !nix.stdenv.isDarwin;
    });

    notmuch = { notmuch, coreutils }@args: let
      notmuch = args.notmuch.super or args.notmuch;
      drv = notmuch.override { emacs = coreutils; };
    in drv.overrideAttrs (old: {
      configureFlags = old.configureFlags or [] ++ [ "--without-emacs" ];

      doCheck = false;

      postInstall = ''
        ${old.postInstall or ""}
        make -C bindings/ruby exec_prefix=$out \
          SHELL=$SHELL \
          $makeFlags ''${makeFlagsArray+"''${makeFlagsArray[@]}"} \
          $installFlags ''${installFlagsArray+"''${installFlagsArray[@]}"} \
          install
        mv $out/lib/ruby/vendor_ruby/* $out/lib/ruby/
        rmdir $out/lib/ruby/vendor_ruby
      '';

      meta = old.meta or {} // {
        broken = old.meta.broken or false || notmuch.stdenv.isDarwin;
        passthru = old.meta.passthru or {} // {
          super = notmuch;
        };
      };
    });
    vim_configurable-pynvim = { vim_configurable, python3 }: vim_configurable.override {
      # vim with python3
      python = python3.withPackages(ps: with ps; [ pynvim ]);
      wrapPythonDrv = true;
      guiSupport = "no";
      luaSupport = false;
      multibyteSupport = true;
      ftNixSupport = false; # provided by "vim-nix" plugin
      # TODO: fully disable X11?
    };

    rxvt_unicode-cvs = { rxvt_unicode, fetchcvs }: rxvt_unicode.overrideAttrs (old: {
      enableParallelBuilding = true;
      src = fetchcvs {
        cvsRoot = ":pserver:anonymous@cvs.schmorp.de:/schmorpforge";
        module = "rxvt-unicode";
        date = "2019-07-01";
        sha256 = "04vgrri1zm5kgjdd4swfi4khjbbp8a3s5c46by7lqg417xqh2a5m";
      };
      meta = old.meta or {} // {
        broken = old.meta.broken or false || !rxvt_unicode.stdenv.isLinux;
      };
    });
    rxvt_unicode-arc = { rxvt_unicode-with-plugins, rxvt_unicode-cvs, pkgs }: (rxvt_unicode-with-plugins.override {
      rxvt_unicode = rxvt_unicode-cvs; # current release is years old, doesn't include 24bit colour changes
      plugins = with pkgs; [
        urxvt_perl
        urxvt_perls
        #urxvt_font_size ?
        urxvt_theme_switch
        urxvt_vtwheel
        urxvt_osc_52
        urxvt_xresources_256
      ];
    }).overrideAttrs (old: {
      meta = old.meta or {} // {
        broken = rxvt_unicode-cvs.meta.broken or false;
      };
    });

    bitlbee-libpurple = { bitlbee }: bitlbee.override { enableLibPurple = true; };

    pidgin-arc = { pidgin, purple-plugins-arc }: let
      wrapped = pidgin.override {
        plugins = purple-plugins-arc;
      };
    in wrapped.overrideAttrs (old: {
      meta = old.meta or {} // {
        broken = pidgin.stdenv.isDarwin;
      };
    });

    buku = { buku }: buku.overrideAttrs (_: {
      doInstallCheck = false;
    });

    weechat-arc = { lib, wrapWeechat, weechat-unwrapped, weechatScripts, python3Packages }: let
      weechat-wrapped = wrapWeechat weechat-unwrapped {
        configure = { availablePlugins, ... }: {
          plugins = with availablePlugins; [
            (python.withPackages (ps: with ps; [
              weechat-matrix
            ]))
          ];
          scripts = with weechatScripts; [
            go auto_away autoconf autosort colorize_nicks unread_buffer urlgrab vimode-git weechat-matrix
          ];
        };
      };
    in weechat-wrapped.overrideAttrs (old: {
        meta = old.meta // {
          broken = old.meta.broken or false || weechat-unwrapped.stdenv.isDarwin || lib.isNixpkgsStable;
        };
    });

    xdg_utils-mimi = { xdg_utils }: xdg_utils.override { mimiSupport = true; };

    luakit-develop = { fetchFromGitHub, luakit, gst_all_1-noqt }: let
      drv = luakit.override {
        gst_all_1 = gst_all_1-noqt;
      };
    in drv.overrideAttrs (old: rec {
      name = "luakit-${version}";
      rev = "8e1363f7f043dce49741c9be7e6b8bf14b9d383b";
      version = "2019-12-20";
      src = fetchFromGitHub {
        owner = "luakit";
        repo = "luakit";
        inherit rev;
        sha256 = "12sxm1vx973i914mk4wj03aa0swc3qqmw842jgsl89lmh4ds2lj2";
      };
    });

    electrum-cli = { lib, electrum }: let
      electrum-cli = electrum.override { enableQt = false; };
    in electrum-cli.overrideAttrs (old: {
      meta = old.meta // {
        broken = old.meta.broken or false || electrum.stdenv.isDarwin;
      };
    });

    duc-cli = { lib, duc }: let
      duc-cli = duc.override { enableCairo = false; };
    in duc-cli.overrideAttrs (old: {
      meta = old.meta // {
        broken = old.meta.broken or false;
      };
    });

    yamllint = { python3Packages }: with python3Packages; toPythonApplication yamllint;
    cargo-download = { lib, hostPlatform, cargo-download, cargo-download-arc }: let
      isBroken = hostPlatform.isDarwin || cargo-download.meta.broken or false == true || !lib.isNixpkgsStable;
    in if isBroken then cargo-download-arc else cargo-download;

    libjaylink = { stdenv, fetchgit, autoreconfHook, pkgconfig, libusb1 }: stdenv.mkDerivation {
      pname = "libjaylink";
      version = "2019-06-07";
      nativeBuildInputs = [ pkgconfig autoreconfHook ];
      buildInputs = [ libusb1 ];

      src = fetchgit {
        #url = "git://git.zapb.de/libjaylink.git"; # appears to be down?
        url = "git://repo.or.cz/libjaylink.git";
        rev = "c2c4bb025f3f02336ea88f57f59e204a1303da9b";
        sha256 = "1qsw1wlkjiqnhqxgddh7l8vawy8170ll6lqrxq7viq91wi9fggsl";
      };
    };

    jimtcl-minimal = { lib, tcl, jimtcl, readline }: (jimtcl.override { SDL = null; SDL_gfx = null; sqlite = null; }).overrideAttrs (old: {
      NIX_CFLAGS_COMPILE = "";
      configureFlags = with lib; filter (f: !hasSuffix "sqlite3" f && !hasSuffix "sdl" f) old.configureFlags;
      propagatedBuildInputs = old.propagatedBuildInputs or [] ++ [ readline ];
      nativeBuildInputs = old.nativeBuildInputs or [] ++ [ tcl ];
    });

    openocd-eclipse = {
      openocd
    , fetchFromGitHub, autoreconfHook, lib
    , git, jimtcl-minimal ? null, libjaylink ? null, enableJaylink ? libjaylink != null
    }: with lib; openocd.overrideAttrs (old: rec {
      pname = "openocd-eclipse";
      name = "openocd-eclipse-${version}";
      version = "0.10.0-12-20190422";

      nativeBuildInputs = old.nativeBuildInputs ++ [ autoreconfHook git jimtcl-minimal ];
      buildInputs = old.buildInputs
        ++ optional enableJaylink libjaylink
        ++ optional (jimtcl-minimal != null) jimtcl-minimal;
      configureFlags = filter (f: !hasSuffix "oocd_trace" f) old.configureFlags
        ++ optional (jimtcl-minimal != null) "--disable-internal-jimtcl"
        ++ optional (!enableJaylink || libjaylink != null) "--disable-internal-libjaylink";

      NIX_LDFLAGS = optional (jimtcl-minimal != null) "-lreadline";

      src = fetchFromGitHub ({
        owner = "gnu-mcu-eclipse";
        repo = "openocd";
        rev = "v${version}";
        sha256 = "08hqb2r58i8v7smw0x0jhlsiaf5hmnaq5igfbcy1p6zbip1prwnp";
      } // optionalAttrs (jimtcl-minimal == null || (enableJaylink && libjaylink == null)) {
        fetchSubmodules = true;
        sha256 = "13g8h2j1vg2dj97mxfiiwch1pw6xsg0r1wc2li3v6j85xvkcf4h9";
      });

      meta = old.meta or {} // {
        broken = old.meta.broken or false || openocd.stdenv.isDarwin;
      };
    });

    kakoune = { kakoune, kakoune-unwrapped ? null }: if kakoune-unwrapped != null
      then kakoune-unwrapped
      else kakoune;

    mustache = { nodeEnv, fetchurl }: nodeEnv.buildNodePackage rec {
      name = "mustache";
      packageName = "mustache";
      version = "3.0.1";
      src = fetchurl {
        url = "https://registry.npmjs.org/${packageName}/-/${packageName}-${version}.tgz";
        sha512 = "2lfq2nlqd738xcb3j7h83ds7wcfz2rwshqx572sy3xk58b39h5sjp2iy82kgc39carra3v2n6kwwdrbzfj4r0xva4fidcai8phkyllc";
      };
      production = true;
    };

    mpd-youtube-dl = { lib, mpd, fetchpatch }: mpd.overrideAttrs (old: {
      pname = "${mpd.pname}-youtube-dl";
      patches = old.patches or [] ++ [ (fetchpatch {
        name = "mpd-youtube-dl.diff";
        url = "https://github.com/MusicPlayerDaemon/MPD/compare/v0.21.16...arcnmx:ytdl-0.21.16.diff";
        sha256 = "1hmchq2wyjpwsry1jb33j3zd1ar7gf57b2vyirgfv15zl5wxvi59";
      }) ];
      meta = old.meta or {} // {
        broken = old.meta.broken or false || lib.versionOlder old.version "0.21" || mpd.stdenv.isDarwin;
      };
    });

    awscli = { awscli, hostPlatform, lib }: awscli.overrideAttrs (old: {
      meta = old.meta // {
        broken = old.meta.broken or false || (hostPlatform.isDarwin && lib.isNixpkgsStable);
      };
    });

    flashplayer-standalone = { flashplayer-standalone, fetchurl }: flashplayer-standalone.overrideAttrs (old: {
      version = "32.0.0.303";
      src = fetchurl {
        url = "https://fpdownload.macromedia.com/pub/flashplayer/updaters/32/flash_player_sa_linux.x86_64.tar.gz";
        sha256 = "0mi3ggv6zhzmdd1h68cgl87n6izhp0pbkhnidd2gl2cp95f23c2d";
      };
    });

    git-revise = { git-revise }: git-revise.overrideAttrs (old: {
      doInstallCheck = false;
    });

    pythonInterpreters = { lib, pythonInterpreters, pkgs }: builtins.mapAttrs (pyname: py: let
      pythonOverrides = import ./python;
      packageOverrides = pself: psuper:
        builtins.mapAttrs (_: drv: pkgs.callPackage drv { pythonPackages = pself; }) (pythonOverrides psuper);
    in if py.pkgs or null != null
      then py.override (old: {
        self = pkgs.pythonInterpreters.${pyname};
        packageOverrides =
          pself: psuper: let
            psuper' = ((old.packageOverrides or (_: _: {})) pself psuper);
          in psuper' // packageOverrides pself (psuper // psuper');
      })
      else py
    ) pythonInterpreters;

    mosh-client = { mosh, stdenvNoCC }: stdenvNoCC.mkDerivation {
      inherit (mosh) name;

      inherit mosh;
      buildCommand = ''
        mkdir -p $out/bin
        ln -s $mosh/share $out/
        ln -s $mosh/bin/mosh $mosh/bin/mosh-client $out/bin/
      '';
    };

    mkShell = { lib, mkShell, mkShellEnv }@args: let
      mkShell = args.mkShell.mkShell or args.mkShell;
    in {
      inherit mkShell;
      mkShellEnv = mkShellEnv.override { inherit mkShell; };
      __functor = self: attrs: lib.drvPassthru (drv: let
        shellEnv = self.mkShellEnv attrs;
      in {
        inherit shellEnv;
        ci = attrs.ci or {} // {
          inputs = attrs.ci.inputs or [] ++ [ shellEnv ];
        };
      }) (self.mkShell attrs);
    };

    # nix progress displays better with the builtin :(
    fetchurl = { fetchurl, nixFetchurl }@args: let
      fetchurl = args.fetchurl.fetchurl or args.fetchurl;
    in {
      inherit fetchurl;
      nixFetchurl = nixFetchurl.override { inherit fetchurl; };
      __functor = self: self.nixFetchurl;
    };
  };
in packages // {
  instantiate = { self, super, ... }: let
    called = builtins.mapAttrs (name: p: let
      fargs = super.lib.functionArgs p;
      args = if fargs ? ${name}
      then {
        ${name} = super.${name} or (if fargs.${name} then null else throw "pkgs.${name} not found");
      } else { };
      # TODO: this messes with the original .override so use lib.callWith instead?
    in self.callPackage p args) packages;
  in called;
}
