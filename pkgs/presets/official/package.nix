{
  dsh,
  extraPlugins ? [ ],
}:
dsh.override {
  inherit extraPlugins;
  meta = {
    description = "Balanced default setup with both CLI and web options";
    descriptions.zh-CN = "默认组合，同时包含命令行和网页选项";
  };
}
