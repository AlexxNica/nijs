{nixpkgs, system}:
{pkgsJsFile, attrName}:

let
  pkgs = import nixpkgs { inherit system; };

  nijsInlineProxy = import ./inlineProxy.nix {
    inherit (pkgs) stdenv writeTextFile nodejs;
  };
in
import (pkgs.stdenv.mkDerivation {
  name = "importPackage-${attrName}.nix";
    
  buildCommand = nijsInlineProxy {
    name = "importPackage-${attrName}-buildCommand";
    requires = [
      { var = "fs"; module = "fs"; }
      { var = "nijs"; module = "${toString ./.}/nijs.js"; }
      { var = "pkgsJsFile"; module = pkgsJsFile; }
    ];
    code = ''
      var expr = pkgsJsFile.pkgs['${attrName}']();
      
      expr = new nijs.NixLet({
        value : {
          pkgs : new nijs.NixExpression('import ${nixpkgs} { system = "${system}"; }'),
          nijsFunProxy : new nijs.NixExpression('import ${toString ./.}/funProxy.nix { inherit (pkgs) stdenv nodejs; }'),
          nijsInlineProxy : new nijs.NixExpression('import ${toString ./.}/inlineProxy.nix { inherit (pkgs) stdenv writeTextFile nodejs; }')
        },
        body : expr
      });

      fs.writeFileSync(process.env['out'], nijs.jsToNix(expr));
    '';
  };
})
