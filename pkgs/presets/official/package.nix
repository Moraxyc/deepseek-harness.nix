{
  dsh,
  extraPlugins ? [ ],
}:
dsh.override { inherit extraPlugins; }
