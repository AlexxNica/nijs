{ nixpkgs ? <nixpkgs>
, systems ? [ "i686-linux" "x86_64-linux" "x86_64-darwin" ]
, officialRelease ? false
}:

let
  pkgs = import nixpkgs {};
  
  version = (builtins.fromJSON ./package.json).version;
  
  jobset = import ./default.nix {
    inherit pkgs;
    system = builtins.currentSystem;
  };
  
  jobs = rec {
    inherit (jobset) tarball;
  
    package = pkgs.lib.genAttrs systems (system:
      (import ./default.nix {
        pkgs = import nixpkgs { inherit system; };
        inherit system;
      }).package
    );
    
    doc = pkgs.stdenv.mkDerivation {
      name = "nijs-docs-${version}";
      src = "${tarball}/tarballs/nijs-${version}.tgz";
    
      buildInputs = [ pkgs.rubyLibs.jsduck ];
      buildPhase = "make duck";
      installPhase = ''
        mkdir -p $out/nix-support
        cp -R build/* $out
        echo "doc api $out" >> $out/nix-support/hydra-build-products
      '';
    };
  
    tests = {
      proxytests = import ./tests/proxytests.nix {
        inherit pkgs;
        nijs = builtins.getAttr (builtins.currentSystem) (jobs.package);
      };
    
      pkgs = 
        let
          pkgsJsFile = "${./.}/tests/pkgs.js";
          
          nijsImportPackage = import ./lib/importPackage.nix {
            inherit nixpkgs;
            system = builtins.currentSystem;
            nijs = builtins.getAttr (builtins.currentSystem) (jobs.package);
          };
        in
        {
          hello = nijsImportPackage { inherit pkgsJsFile; attrName = "hello"; };
          zlib = nijsImportPackage { inherit pkgsJsFile; attrName = "zlib"; };
          file = nijsImportPackage { inherit pkgsJsFile; attrName = "file"; };
          perl = nijsImportPackage { inherit pkgsJsFile; attrName = "perl"; };
          openssl = nijsImportPackage { inherit pkgsJsFile; attrName = "openssl"; };
          curl = nijsImportPackage { inherit pkgsJsFile; attrName = "curl"; };
          wget = nijsImportPackage { inherit pkgsJsFile; attrName = "wget"; };
          sumTest = nijsImportPackage { inherit pkgsJsFile; attrName = "sumTest"; };
          stringWriteTest = nijsImportPackage { inherit pkgsJsFile; attrName = "stringWriteTest"; };
          appendFilesTest = nijsImportPackage { inherit pkgsJsFile; attrName = "appendFilesTest"; };
          createFileWithMessageTest = nijsImportPackage { inherit pkgsJsFile; attrName = "createFileWithMessageTest"; };
          sayHello = nijsImportPackage { inherit pkgsJsFile; attrName = "sayHello"; };
          addressPerson = nijsImportPackage { inherit pkgsJsFile; attrName = "addressPerson"; };
          addressPersons = nijsImportPackage { inherit pkgsJsFile; attrName = "addressPersons"; };
          addressPersonInformally = nijsImportPackage { inherit pkgsJsFile; attrName = "addressPersonInformally"; };
          numbers = nijsImportPackage { inherit pkgsJsFile; attrName = "numbers"; };
          sayHello2 = nijsImportPackage { inherit pkgsJsFile; attrName = "sayHello2"; };
          objToXML = nijsImportPackage { inherit pkgsJsFile; attrName = "objToXML"; };
          conditionals = nijsImportPackage { inherit pkgsJsFile; attrName = "conditionals"; };
          bzip2 = nijsImportPackage { inherit pkgsJsFile; attrName = "bzip2"; };
          utillinux = nijsImportPackage { inherit pkgsJsFile; attrName = "utillinux"; };
          python = nijsImportPackage { inherit pkgsJsFile; attrName = "python"; };
          nodejs = nijsImportPackage { inherit pkgsJsFile; attrName = "nodejs"; };
          optparse = nijsImportPackage { inherit pkgsJsFile; attrName = "optparse"; };
          slasp = nijsImportPackage { inherit pkgsJsFile; attrName = "slasp"; };
          nijs = nijsImportPackage { inherit pkgsJsFile; attrName = "nijs"; };
        };
    
      pkgsAsync =
        let
          pkgsJsFile = "${./.}/tests/pkgs-async.js";
          
          nijsImportPackageAsync = import ./lib/importPackageAsync.nix {
            inherit nixpkgs;
            system = builtins.currentSystem;
            nijs = builtins.getAttr (builtins.currentSystem) (jobs.package);
          };
        in
        {
          test = nijsImportPackageAsync { inherit pkgsJsFile; attrName = "test"; };
          hello = nijsImportPackageAsync { inherit pkgsJsFile; attrName = "hello"; };
          zlib = nijsImportPackageAsync { inherit pkgsJsFile; attrName = "zlib"; };
          file = nijsImportPackageAsync { inherit pkgsJsFile; attrName = "file"; };
          createFileWithMessageTest = nijsImportPackageAsync { inherit pkgsJsFile; attrName = "createFileWithMessageTest"; };
        };
    
      execute =
        let
          nijs = builtins.getAttr (builtins.currentSystem) package;
          documentRoot = pkgs.stdenv.mkDerivation {
            name = "documentroot";
            
            srcHello = pkgs.fetchurl {
              url = mirror://gnu/hello/hello-2.9.tar.gz;
              sha256 = "19qy37gkasc4csb1d3bdiz9snn8mir2p3aj0jgzmfv0r2hi7mfzc";
            };
            
            srcZlib = pkgs.fetchurl {
              url = mirror://sourceforge/libpng/zlib/1.2.8/zlib-1.2.8.tar.gz;
              sha256 = "039agw5rqvqny92cpkrfn243x2gd4xn13hs3xi6isk55d2vqqr9n";
            };
            
            srcFile = pkgs.fetchurl {
              url = ftp://ftp.astron.com/pub/file/file-5.19.tar.gz;
              sha256 = "0z1sgrcfy6d285kj5izy1yypf371bjl3247plh9ppk0svaxv714l";
            };
            
            buildCommand = ''
              mkdir -p $out/hello
              cp $srcHello $out/hello/hello-2.9.tar.gz
              mkdir -p $out/libpng/zlib/1.2.8
              cp $srcZlib $out/libpng/zlib/1.2.8/zlib-1.2.8.tar.gz
              mkdir -p $out/pub/file
              cp $srcFile $out/pub/file/file-5.19.tar.gz
            '';
          };
        in
        with import "${nixpkgs}/nixos/lib/testing.nix" { system = builtins.currentSystem; };

        simpleTest {
          nodes = {
            machine = {pkgs, ...}:
            
            {
              networking.extraHosts = ''
                127.0.0.2 ftpmirror.gnu.org prdownloads.sourceforge.net ftp.astron.com
              '';
              
              services.httpd.enable = true;
              services.httpd.adminAddr = "admin@localhost";
              services.httpd.documentRoot = documentRoot;
              
              services.vsftpd.enable = true;
              services.vsftpd.anonymousUser = true;
              services.vsftpd.anonymousUserHome = "/home/ftp";
              
              environment.systemPackages = [ nijs pkgs.stdenv pkgs.gcc pkgs.gnumake ];
            };
          };
          testScript = 
            ''
              startAll;
              
              # Unpack the tarball to retrieve the testcases
              $machine->mustSucceed("tar xfvz ${tarball}/tarballs/*.tgz");
              
              # Build the 'test' package and check whether the output contains
              # 'Hello world'
              my $result = $machine->mustSucceed("cd package/tests && nijs-execute pkgs-async.js -A test");
              $machine->mustSucceed("[ \"\$(cat ".(substr $result, 0, -1)." | grep 'Hello world')\" != \"\" ]");
              
              # Build GNU Hello and see whether we can run it
              $machine->waitForJob("httpd");
              $result = $machine->mustSucceed("cd package/tests && nijs-execute pkgs-async.js -A hello");
              $machine->mustSucceed("\$HOME/.nijs/store/hello-*/bin/hello");
              
              # Build file and its dependencies (zlib) and see whether we can
              # run it
              $machine->mustSucceed("cp -r ${documentRoot}/pub /home/ftp");
              $machine->waitForJob("vsftpd");
              $result = $machine->mustSucceed("cd package/tests && nijs-execute pkgs-async.js -A file");
              $machine->mustSucceed("\$HOME/.nijs/store/file-*/bin/file --version");
              
              # Two of file's shared libraries (libmagic and libz) should refer to the NiJS store
              $machine->mustSucceed("[ \"\$(ldd \$HOME/.nijs/store/file-*/bin/file | grep -c \$HOME/.nijs/store)\" = \"2\" ]");
            '';
        };
    };
  };
in
jobs
