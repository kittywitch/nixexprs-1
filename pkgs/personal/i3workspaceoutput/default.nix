{ package, wrapShellScriptBin, i3, jq }:
package (wrapShellScriptBin "i3workspaceoutput" ./i3workspaceoutput.sh) {
  depsRuntimePath = [i3 jq];
}