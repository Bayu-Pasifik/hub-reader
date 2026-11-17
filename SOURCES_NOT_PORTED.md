# Sumber yang belum di-port / Sources not yet ported

Dibuat 2026-11-17 dari perbandingan `keiyoushi/extensions-source` (folder `src/en` dan `src/id`) dengan katalog Hub Reader (`assets/sources/catalog.json` + sumber Dart tulis tangan).
Generated 2026-11-17 by diffing `keiyoushi/extensions-source` (`src/en` and `src/id`) against the Hub Reader catalog (`assets/sources/catalog.json` + hand-written Dart sources).

| Bahasa / Language | Belum di-port / Not ported |
|---|---|
| Indonesia (id) | 14 (6 sudah di-port: Bacami, MG Komik, West Manga, Komik AV, Hentai Crot, Pix Hentai) |
| English (en) | 252 |

> Catatan / Notes
> - ID: Pencocokan berdasarkan nama folder dan nama tampilan; beberapa situs bisa salah terdeteksi. Sumber multi-bahasa (`all`) tidak termasuk.
> - EN: Matching uses folder name and display name, so a few sites may be misdetected. Multi-language (`all`) sources are excluded.
> - ID: Hampir semua sumber di sini kustom (bukan template), jadi tiap situs butuh parser Dart sendiri. Banyak situs Inggris adalah webcomic satu-situs, situs resmi berbayar/login (Kodansha, VIZ, BookWalker, dll.), atau situs hentai.
> - EN: Nearly all of these are custom (non-template) sources, so each needs its own Dart parser. Many English entries are single-site webcomics, paid or login-gated official stores (Kodansha, VIZ, BookWalker, etc.), or hentai sites.

---

## 1. Indonesia (id) — 14 sumber / sources

#### Aman / Safe (6)

| # | Nama / Name | Situs / Site | Catatan / Note |
|---|---|---|---|
| 2 | Komiku.com | https://01.komiku.asia | Dicoba lalu dihapus: gambar diblokir tantangan Cloudflare. / Tried then removed: images blocked by Cloudflare challenge. |
| 4 | Softkomik | - | Tidak di-port: sesi API bertanda tangan + dekripsi CryptoJS. / Not ported: signed API sessions + CryptoJS decryption. |
| 5 | VoraToon | - | Dicoba lalu dihapus: gambar bab gagal diekstrak dari RSC. / Tried then removed: chapter images could not be extracted from RSC. |

#### Campuran / Mixed (8)

| # | Nama / Name | Situs / Site | Catatan / Note |
|---|---|---|---|
| 1 | CGBUM | https://cgbum.com | Tidak di-port: gambar bab dilindungi tantangan proof-of-work. / Not ported: chapter images gated by a proof-of-work challenge. |
| 2 | Comicaso | https://v3.comicaso.pro | Tidak di-port: API meminta tantangan verifikasi. / Not ported: API demands a verification challenge. |
| 3 | CosmicScans | https://04.cosmicscans.to | Tidak di-port: sesi gambar memakai Turnstile. / Not ported: image sessions require Turnstile. |
| 5 | KomikNesia | https://v2.komiknesiaku.com | Situs mati saat dicek (HTTP 521). / Site down when checked (HTTP 521). |
| 6 | Manhwa Indo | https://www.manhwaindo.my | Dicoba lalu dihapus: CDN gambar memblokir klien. / Tried then removed: image CDN blocks the client. |
| 7 | MikoRoku | https://mikoroku.com | Situs error saat dicek (HTTP 500). / Site erroring when checked (HTTP 500). |
| 8 | Pramramadhan | https://01.pramramadhan.my.id | Situs tidak terjangkau. / Site unreachable. |

#### Dewasa (NSFW) / Adult (NSFW) (6)

| # | Nama / Name | Situs / Site | Catatan / Note |
|---|---|---|---|
| 1 | Doujindesu | - | Tidak di-port: API memakai rahasia aplikasi + dekripsi XOR. / Not ported: API uses an app secret + XOR decryption. |
| 3 | KumoPoi | - | Dicoba lalu dihapus: halaman palsu (honeypot) untuk klien non-browser. / Tried then removed: honeypot pages for non-browser clients. |
| 5 | Ryukomik | https://ryukomik.my.id | Situs tidak terjangkau. / Site unreachable. |
| 6 | Story About Us | https://storyabout-us.com | Tidak di-port: bab berupa PDF yang dirender di perangkat. / Not ported: chapters are PDFs rendered on-device. |

---

## 2. English (en) — 252 sumber / sources

#### Aman / Safe (100)

| # | Nama / Name | Situs / Site | Catatan / Note |
|---|---|---|---|
| 1 | Aethon Webcomics | https://aethonwebcomics.com |  |
| 2 | Alpha Manga | https://www.alpha-manga.com |  |
| 3 | Arknights Comics | https://arknights.global |  |
| 4 | Arven Scans | https://arvenscans.net |  |
| 5 | aurora | https://comicaurora.com |  |
| 6 | Baetoon | https://baetoon.com |  |
| 7 | Bakkin Self-hosted | - | template: bakkin |
| 8 | BatCave | https://batcave.biz |  |
| 9 | Broccoli Soup | https://politeandgood.com |  |
| 10 | Character Design References | https://characterdesignreferences.com |  |
| 11 | Clone Manga | https://manga.clone-army.org |  |
| 12 | Clown Corps | https://clowncorps.net |  |
| 13 | Collected Curios | https://www.collectedcurios.com |  |
| 14 | Colorized Mangas | https://colorizedmangas.com |  |
| 15 | ComicHubFree | https://comichubfree.com |  |
| 16 | Comivex | https://comivex.com |  |
| 17 | Complex Bowler | https://complexbowler.neocities.org |  |
| 18 | Cyanide & Happiness | https://explosm.net |  |
| 19 | Dark Legacy Comics | https://www.darklegacycomics.com |  |
| 20 | Dark Science | https://dresdencodak.com |  |
| 21 | Darths & Droids | https://www.darthsanddroids.net |  |
| 22 | Digital Comic Museum | https://digitalcomicmuseum.com |  |
| 23 | El Goonish Shive | https://www.egscomics.com |  |
| 24 | Elan School | https://elan.school |  |
| 25 | Existential Comics | https://existentialcomics.com |  |
| 26 | Gone with the Blastwave | https://www.blastwave-comic.com |  |
| 27 | Grrl Power Comic | https://www.grrlpowercomic.com |  |
| 28 | Gunnerkrigg Court | https://www.gunnerkrigg.com |  |
| 29 | Hiveworks Comics | https://hiveworkscomics.com |  |
| 30 | HonkaiImpact3 | https://manga.honkaiimpact3.com |  |
| 31 | HYPERCOMIC | https://play.hypercomic.io |  |
| 32 | I'm An Evil God | https://imanevilgod.com |  |
| 33 | Infinite-Scan | https://www.infinite-scan.com |  |
| 34 | J-Novel | https://j-novel.club |  |
| 35 | K Manga | https://kmanga.kodansha.com |  |
| 36 | Kaiji Manga Online | https://w9.kaijimanga.com |  |
| 37 | keenspot | https://twokinds.keenspot.com |  |
| 38 | Kill Six Billion Demons | https://killsixbilliondemons.com |  |
| 39 | Leslie&Victims | https://leslie-victims.pages.dev |  |
| 40 | Loading Artist | https://loadingartist.com |  |
| 41 | LoLoBun | https://www.lolobun.com |  |
| 42 | Luminare Translations | https://luminaretranslations.com |  |
| 43 | LuxManga | https://luxmanga.net |  |
| 44 | Madokami | https://manga.madokami.al |  |
| 45 | Manga Demon | https://demonicscans.org |  |
| 46 | MangaBolt | https://mangabolt.com |  |
| 47 | MangaCherri | https://mangacherri.com |  |
| 48 | Mangack | https://mangack.com |  |
| 49 | MangaCloud | https://mangacloud.org |  |
| 50 | Mangamo | https://www.mangamo.com |  |
| 51 | MangaYi | https://mangayi.com |  |
| 52 | ManhuaPlus.top | https://manhuaplus.top |  |
| 53 | Megatokyo | https://megatokyo.com |  |
| 54 | MLBB Lore | https://play.mobilelegends.com |  |
| 55 | Monochrome Custom | - | template: monochrome |
| 56 | Ninko Comics | https://ninkocomics.com |  |
| 57 | Nuvia Toon | https://nuviatoon.org |  |
| 58 | Nux Scans | https://nuxscans-comics.blogspot.com |  |
| 59 | O Translations | https://otl.moe |  |
| 60 | One Punch Man Online | https://w21.1punchman.com |  |
| 61 | oots | https://www.giantitp.com |  |
| 62 | OriYami | https://oriyami.com |  |
| 63 | Patch Friday | https://patchfriday.com |  |
| 64 | Philia Scans | https://philiascans.org |  |
| 65 | Questionable Content | https://www.questionablecontent.net |  |
| 66 | Randowiz | https://randowis.com |  |
| 67 | Read Comics Online | https://readcomicsonline.ru | template: mmrcms |
| 68 | Read Horimiya Online | https://read-horimiya.online |  |
| 69 | Read Maid Sama Manga Online | https://w14.maid-sama.com |  |
| 70 | Read The Beginning After The End Manga Online | https://w22.thebeginningaftertheendmanga.com |  |
| 71 | Read The Exiled Heavy Knight Manga Online | https://w3.theexiledheavyknight.com |  |
| 72 | Read Vagabond Manga | https://readbagabondo.com |  |
| 73 | ReadComicsOnline.lol | https://readcomicsonline.lol |  |
| 74 | Real Life Comics | https://reallifecomics.com |  |
| 75 | Renascans | https://renascans.net |  |
| 76 | Rinko Comics | https://rinkocomics.com |  |
| 77 | RuriDragon Manga Online | https://w2.ruridragon.com |  |
| 78 | Sabrina Online | https://www.sabrina-online.com |  |
| 79 | Saturday Morning Breakfast Comics | https://smbc-comics.com |  |
| 80 | Schlock Mercenary | https://www.schlockmercenary.com |  |
| 81 | Snafu Comics | https://www.snafu-comics.com |  |
| 82 | Solar and Sundry | https://sas-api.fly.dev |  |
| 83 | StoneScape | https://stonescape.xyz |  |
| 84 | SUPER MEGA | https://www.supermegacomics.com |  |
| 85 | Swords Comic | https://swordscomic.com |  |
| 86 | The Draw Play | https://www.thedrawplay.com |  |
| 87 | The Far Side | https://www.thefarside.com |  |
| 88 | The Girl from Random Chatting Manga Online | https://thegirlfromrandomchatting.com |  |
| 89 | The Interpretation of Shadows | https://tioscomic.com |  |
| 90 | The Property of Hate | https://jolleycomics.com |  |
| 91 | The Wandering Inn | https://webcomic.wanderinginn.com |  |
| 92 | ToonGrab | https://toongrab.com |  |
| 93 | vgperson | https://vgperson.com |  |
| 94 | Vision Haze | https://www.visionhaze.com |  |
| 95 | VIZ | https://www.viz.com |  |
| 96 | Voyce.Me | https://www.voyce.me |  |
| 97 | War For Rayuba | https://xrabohrok.github.io/WarMap/#/ |  |
| 98 | Webdex Scans | https://webdexscans.com |  |
| 99 | WebNovel | https://www.webnovel.com |  |
| 100 | ZipComic | https://www.zipcomic.com |  |

#### Campuran / Mixed (73)

| # | Nama / Name | Situs / Site | Catatan / Note |
|---|---|---|---|
| 1 | AllManga | https://mkissa.to |  |
| 2 | Atsumaru | https://atsu.moe |  |
| 3 | Bakaloli | https://bakaloli.eu |  |
| 4 | Bbato | - |  |
| 5 | BookWalker | https://bookwalker.com |  |
| 6 | Chikari | https://chikari.moe |  |
| 7 | Coffee Manga (Unoriginal) | https://coffeemanga.net | template: imperiomanhwa |
| 8 | ComicK Fanmade | https://comickfan.com |  |
| 9 | ComicLand | https://comicland.org |  |
| 10 | Comix | - |  |
| 11 | Coolmic | https://coolmic.me |  |
| 12 | Dashtoon | https://dashtoon.com |  |
| 13 | Dream-Manga | https://dream-manga.com |  |
| 14 | Dynasty Scans | https://dynasty-scans.com |  |
| 15 | EbookRenta | https://www.ebookrenta.com |  |
| 16 | emaqi | https://emaqi.com |  |
| 17 | Extra Fabulous Comics | https://www.extrafabulouscomics.com |  |
| 18 | Hyakuro Translations | https://hyakuro.net |  |
| 19 | InfinityScans | https://infinityscans.org |  |
| 20 | Inkora | https://inkora.spacely.tech |  |
| 21 | INKR | https://comics.inkr.com |  |
| 22 | KaliScans.org (unoriginal) | https://kaliscans.org |  |
| 23 | Kappa Beast | https://kappabeast.com |  |
| 24 | Kemono Café | https://kemono.cafe |  |
| 25 | Kodansha | https://kodansha.us |  |
| 26 | Komix | https://komix.to |  |
| 27 | KuraManga | https://kuramanga.com |  |
| 28 | Lazy Monki Scans | https://lazy-monki-scans.netlify.app |  |
| 29 | LustToon | https://lustoon.com |  |
| 30 | Manga MTL | https://mtlmanga.org | template: manhuarm |
| 31 | Manga-Bay | https://manga-bay.biz |  |
| 32 | Manga.uno | https://manga.uno |  |
| 33 | MangaDE | https://mangade.io |  |
| 34 | MangaFox | https://fanfox.net |  |
| 35 | MangaGeko | https://www.mgeko.cc |  |
| 36 | Mangago | https://www.mangago.me |  |
| 37 | Mangahere | https://www.mangahere.cc |  |
| 38 | MangaHome | https://www.mangahome.com |  |
| 39 | MangaLix | https://mangalix.com |  |
| 40 | MangaMelon | https://mangamelon.com |  |
| 41 | MangaPlaza | https://mangaplaza.com |  |
| 42 | Mangastash | https://mangastash.org |  |
| 43 | Mangatown | https://www.mangatown.com |  |
| 44 | ManhuaTop | https://manhuatop.org |  |
| 45 | ManhwaRead | - |  |
| 46 | ManhwaZ | https://manhwaz.cc |  |
| 47 | ManhwaZone | https://manhwazone.com |  |
| 48 | MyMangaList | https://www5.mymangalist.org |  |
| 49 | New Manhwa | https://saymanhwa.com |  |
| 50 | NexComic | https://nexcomic.com |  |
| 51 | OceComic | https://ocecomic.com |  |
| 52 | Omoi | https://www.omoi.com |  |
| 53 | Oppai Stream | https://read.oppai.stream |  |
| 54 | ReiManga | https://reimanga.net |  |
| 55 | SACACHISPA | https://sacachispa.site |  |
| 56 | ScansGG | https://scans.gg |  |
| 57 | Schale Scans | https://www.schalescans.com |  |
| 58 | SilentQuill | https://silentquill.net |  |
| 59 | StreameX (unoriginal) | https://streamex.hn |  |
| 60 | Tapas | https://tapas.io |  |
| 61 | Team Shadowi | https://www.team-shadowi.com |  |
| 62 | The Duck Webcomics | https://www.theduckwebcomics.com |  |
| 63 | Tinyview | https://tinyview.com |  |
| 64 | TodayManga | https://todaymanga.com |  |
| 65 | Toon Hub | https://toon-hub.com |  |
| 66 | Toonkotsu | https://toonkotsu.com |  |
| 67 | Toonz/Toonx | https://toonz.to |  |
| 68 | VyvyManga | - |  |
| 69 | Webnex | https://webnex.cc |  |
| 70 | WebtoonClub | https://webtoonclub.com |  |
| 71 | WebtoonLib | https://webtoonlib.to |  |
| 72 | XoManga | https://www.xomanga.site |  |
| 73 | Yurivan | https://www.yurivan.com |  |

#### Dewasa (NSFW) / Adult (NSFW) (79)

| # | Nama / Name | Situs / Site | Catatan / Note |
|---|---|---|---|
| 1 | 8Muses | https://comics.8muses.com | template: eromuse |
| 2 | 8Muses (unoriginal) | https://8muses.xxx |  |
| 3 | Asuratoons (unoriginal) | https://www.asuratoons.info |  |
| 4 | Babes Rater | https://babesrater.com |  |
| 5 | BabeSource | https://babesource.com |  |
| 6 | buttsmithy | https://incase.buttsmithy.com |  |
| 7 | Cutie Comics | https://cutiecomics.com |  |
| 8 | DesireScans | https://desirescans.com |  |
| 9 | Doujin.io - J18 | https://doujin.io |  |
| 10 | Doujins | https://doujins.com |  |
| 11 | EAHentai | https://eahentai.com |  |
| 12 | Eggporncomics | https://eggporncomics.com |  |
| 13 | Erofus | https://www.erofus.com | template: eromuse |
| 14 | Fairies vs Tentacles | https://eldrikdgt.com |  |
| 15 | Futapo | https://futapo.com |  |
| 16 | Gensura | https://gensura.net |  |
| 17 | GirlsTop | https://en.girlstop.info |  |
| 18 | HD Porn Comics | https://hdporncomics.com |  |
| 19 | Hentai.yoga | https://hentai.yoga |  |
| 20 | Hentai18 | https://hentai18.net |  |
| 21 | HentaiDad | https://hentaidad.com |  |
| 22 | HentaiFC | https://hentaifc.com |  |
| 23 | HentaiForce | https://hentaiforce.net |  |
| 24 | HentaiFull | https://hentaifull.net |  |
| 25 | HentaiHere | https://hentaihere.com |  |
| 26 | HentaiKisu | https://hentaikisu.com |  |
| 27 | HentaiKun | https://hentaikun.com |  |
| 28 | HentaiNexus | https://hentainexus.com |  |
| 29 | HentaiPill | https://hentaipill.com |  |
| 30 | HentaiRead | https://hentairead.com |  |
| 31 | HentaiRead.io | https://hentairead.io |  |
| 32 | HentaiSco | https://hentaisco.cc |  |
| 33 | HentaiTnT | https://hentaitnt.net |  |
| 34 | Hentara | https://hentara.com |  |
| 35 | HotComics | https://hotcomics.io |  |
| 36 | I Roved Out | https://www.irovedout.com |  |
| 37 | ILikeComix | https://ilikecomix.com |  |
| 38 | KingComiX | https://kingcomix.com |  |
| 39 | Kotokotek | https://kotokotek.wixsite.com |  |
| 40 | LGBToon | https://lgbtoon.com |  |
| 41 | Mahouirexnohentaikarte | https://mahouirexnohentaikarte.com |  |
| 42 | Manhwa18 | https://manhwa18.com |  |
| 43 | Manhwa18Dash | https://manhwa18dash.com |  |
| 44 | Manhwa210 | https://manhwa210.com |  |
| 45 | ManhwaH | https://manhwah.com |  |
| 46 | Manhwalike | https://manhwalike.com |  |
| 47 | ManhwaX (unoriginal) | https://manhwax.pro |  |
| 48 | Mehgazone | https://mehgazone.com |  |
| 49 | Milftoon | https://milftoon.xxx |  |
| 50 | Multporn | https://multporn.net |  |
| 51 | MyAdultComics | https://myadultcomics.com |  |
| 52 | MyHentaiComics | https://myhentaicomics.com |  |
| 53 | MyHentaiGallery | https://myhentaigallery.com |  |
| 54 | Myth Toons | https://mythtoons.org |  |
| 55 | NineHentai | https://9hentai.so |  |
| 56 | Nortverse | https://nortverse.com |  |
| 57 | Oglaf | https://www.oglaf.com |  |
| 58 | Oh Joy Sex Toy | https://www.ohjoysextoy.com |  |
| 59 | Only The Best Hentai | https://onlythebesthentai.com |  |
| 60 | Paradise Scans | https://paradisescans.com |  |
| 61 | PornComix | https://bestporncomix.com |  |
| 62 | Pornhwa.me | https://pornhwa.me |  |
| 63 | Pornhwa18 | https://pornhwa18.com |  |
| 64 | PornhwaDB Reader | https://pornhwareader.com |  |
| 65 | Revival Scans | https://www.revivalscans.com |  |
| 66 | Rule34Comic | https://rule34comic.party |  |
| 67 | SpyFakku | - |  |
| 68 | Sunshine Butterfly Scans | https://wings.sbs |  |
| 69 | Tailspace | https://tailspace.com |  |
| 70 | Temple Scan | https://templetoons.com |  |
| 71 | The Blank | https://theblank.net | template: pam |
| 72 | ToonHey | https://toonhey.com |  |
| 73 | Transfusions | https://transfusionscomic.com |  |
| 74 | Vixen Logic | https://www.vixenlogic.com |  |
| 75 | Webtoon Hentai (unoriginal) | https://webtoonhentai.org |  |
| 76 | XlecX | https://xlecx.one |  |
| 77 | XYZ Comics | https://xyzcomics.com |  |
| 78 | YaoiHot | https://yaoihot.com |  |
| 79 | Yiff Comics (unoriginal) | https://yiff-comics.com |  |
