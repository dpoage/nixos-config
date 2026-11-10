# Color mixing for consumers that need a derived color (Stylix has no helper).
#   mixHex a b pct: 6-hex strings (no '#'); pct = percent of b, 0..100.
# Result is 6 lowercase hex digits without '#'. Light palettes use it to pull
# pale accents toward the text color by a fixed percentage.
{ lib }:
let
  chan = hex: i: (lib.fromHexString (builtins.substring (2 * i) 2 hex));
  pad = h: if builtins.stringLength h == 1 then "0${h}" else h;
in
{
  mixHex = a: b: pct:
    lib.concatMapStrings
      (i: pad (lib.toLower (lib.toHexString ((chan a i * (100 - pct) + chan b i * pct + 50) / 100))))
      [ 0 1 2 ];
}
