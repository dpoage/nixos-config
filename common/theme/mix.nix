# mixHex { from, toward, pct }: `from` moved pct% (integer 0..100) toward
# `toward`; both 6 hex digits without '#'. Returns 6 lowercase hex digits.
# Stylix has no color-mixing helper.
{ lib }:
let
  chan = hex: i: (lib.fromHexString (builtins.substring (2 * i) 2 hex));
  pad = h: if builtins.stringLength h == 1 then "0${h}" else h;
  hex6 = name: v:
    if builtins.isString v && builtins.match "[0-9a-fA-F]{6}" v != null then v
    else throw "mixHex: ${name} must be 6 hex digits without '#', got ${builtins.toJSON v}";
in
{
  mixHex = { from, toward, pct }:
    let
      a = hex6 "from" from;
      b = hex6 "toward" toward;
      p =
        if builtins.isInt pct && pct >= 0 && pct <= 100 then pct
        else throw "mixHex: pct must be an integer in 0..100, got ${builtins.toJSON pct}";
    in
    lib.concatMapStrings
      (i: pad (lib.toLower (lib.toHexString ((chan a i * (100 - p) + chan b i * p + 50) / 100))))
      [ 0 1 2 ];
}
