# Stand-in for the private git+ssh pattern-cli input so CI can evaluate the
# hosts without credentials (`--override-input pattern-cli path:./ci/pattern-cli-stub`).
# The overlay only uses the input as a source tree, so an empty flake suffices.
{
  outputs = _: { };
}
