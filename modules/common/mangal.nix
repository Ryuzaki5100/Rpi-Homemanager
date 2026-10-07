{ config, ... }:

{
  xdg.configFile."mangal/mangal.toml".text = ''
    [downloader]
    path = "${config.home.homeDirectory}/manga"
    create_manga_dir = true

    [formats]
    use = "pdf"

    [mangadex]
    language = "en"
    nsfw = false
  '';
}
