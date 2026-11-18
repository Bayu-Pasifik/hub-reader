import {
  Archive,
  BookOpen,
  Download,
  Github,
  Globe,
  Heart,
  History,
  Layers,
  Link as LinkIcon,
  Lock,
  Maximize,
  Smartphone,
} from 'lucide-react'
import { Button } from './components/ui/button'
import { Card } from './components/ui/card'
import { Badge } from './components/ui/badge'
import { Marquee } from './components/ui/marquee'
import { Accordion } from './components/ui/accordion'

const REPO = 'https://github.com/Bayu-Pasifik/hub-reader'
const RELEASE = `${REPO}/releases/latest`
const ICON = `${import.meta.env.BASE_URL}icon.png`

const features = [
  {
    icon: Layers,
    tone: 'sun',
    title: '560+ sumber komik',
    text: 'Madara, MangaThemesia, Keyoapp, dan puluhan template lain. Katalog diperbarui dari repo tiap 12 jam, tanpa update APK.',
  },
  {
    icon: BookOpen,
    tone: 'mint',
    title: 'Novel via plugin',
    text: 'Plugin LNReader jalan di perangkat. Baca novel web, impor EPUB lokal, dan ekspor ke EPUB.',
  },
  {
    icon: Smartphone,
    tone: 'pink',
    title: 'Tanpa server',
    text: 'Konten diambil langsung dari situs sumbernya di HP kamu. Tidak ada akun, tidak ada server perantara.',
  },
  {
    icon: Heart,
    tone: 'white',
    title: 'Favorit & riwayat',
    text: 'Simpan seri kesukaan, lanjut dari bab terakhir. Favorit lama ikut pindah saat situs ganti domain.',
  },
  {
    icon: LinkIcon,
    tone: 'sun',
    title: 'Sinkron tracker',
    text: 'Terhubung ke AniList, MyAnimeList, Kitsu, dan MangaUpdates untuk mencatat progres bacaanmu.',
  },
  {
    icon: Maximize,
    tone: 'mint',
    title: 'Pembaca layar penuh',
    text: 'Mode layar penuh untuk komik dan novel. Fokus ke halaman, bukan ke bilah menu.',
  },
  {
    icon: Archive,
    tone: 'pink',
    title: 'Unduhan & cadangan',
    text: 'Unduh bab untuk dibaca offline, lalu cadangkan dan pulihkan datamu kapan saja.',
  },
  {
    icon: Lock,
    tone: 'white',
    title: 'Kunci aplikasi',
    text: 'Amankan perpustakaanmu dengan kunci. Sumber 18+ disembunyikan secara default.',
  },
]

const steps = [
  { n: '01', title: 'Unduh APK', text: 'Buka halaman rilis, pilih APK sesuai ABI HP. Kebanyakan HP memakai arm64-v8a.' },
  { n: '02', title: 'Pasang', text: 'Izinkan pemasangan dari browser, lalu ketuk file APK yang sudah diunduh.' },
  { n: '03', title: 'Baca', text: 'Pilih sumber di tab Komik atau Novel, cari judul, dan mulai membaca.' },
]

const faqs = [
  {
    q: 'Apakah Hub Reader gratis?',
    a: 'Ya. Aplikasi ini gratis dan kode sumbernya terbuka di GitHub.',
  },
  {
    q: 'Apakah tersedia untuk iPhone?',
    a: 'Belum. Hub Reader dibuat dengan Flutter dan saat ini dirilis sebagai APK Android.',
  },
  {
    q: 'APK mana yang harus kuunduh?',
    a: 'Untuk kebanyakan HP, pilih arm64-v8a. HP lama 32-bit memakai armeabi-v7a. Bingung? Pakai APK universal.',
  },
  {
    q: 'Kenapa ada sumber yang gagal dimuat?',
    a: 'Aplikasi membaca situs sumbernya langsung. Situs bisa mati, pindah domain, atau minta verifikasi Cloudflare (ketuk Buka di WebView). Sumber rusak bisa dilaporkan dari layar errornya.',
  },
  {
    q: 'Apakah ada konten 18+?',
    a: 'Sumber 18+ disembunyikan secara default. Aktifkan sendiri lewat Pengaturan, Sumber, Tampilkan sumber NSFW.',
  },
]

const marqueeItems = ['Komik', 'Novel', 'Madara', 'MangaThemesia', 'Keyoapp', 'EPUB', 'AniList', 'MyAnimeList', 'Kitsu', 'Offline']

function Nav() {
  return (
    <header className="sticky top-0 z-50 border-b-[3px] border-ink bg-paper/95 backdrop-blur">
      <div className="mx-auto flex h-16 max-w-6xl items-center justify-between px-4">
        <a href="#top" className="flex items-center gap-3 text-xl font-bold">
          <img src={ICON} alt="" className="size-9 rounded-md border-[3px] border-ink" />
          Hub Reader
        </a>
        <nav className="hidden items-center gap-6 font-bold md:flex">
          <a href="#fitur" className="hover:underline decoration-4 underline-offset-4">Fitur</a>
          <a href="#cara" className="hover:underline decoration-4 underline-offset-4">Cara pasang</a>
          <a href="#faq" className="hover:underline decoration-4 underline-offset-4">FAQ</a>
        </nav>
        <Button href={RELEASE} size="sm">
          <Download className="size-4" strokeWidth={3} /> Unduh
        </Button>
      </div>
    </header>
  )
}

function PhoneMock() {
  return (
    <div className="relative mx-auto w-64 animate-float sm:w-72">
      <div className="rounded-[2rem] border-[4px] border-ink bg-white p-3 shadow-brutal-lg">
        <div className="mx-auto mb-3 h-2 w-16 rounded-full bg-ink" />
        <div className="space-y-3">
          <div className="flex items-center justify-between rounded-md border-[3px] border-ink bg-sun px-3 py-2 font-bold">
            <span>Komik</span>
            <Globe className="size-4" strokeWidth={3} />
          </div>
          <div className="grid grid-cols-2 gap-3">
            {['bg-pink', 'bg-mint', 'bg-sun', 'bg-paper'].map((c, i) => (
              <div key={i} className="space-y-1">
                <div className={`aspect-[3/4] rounded-md border-[3px] border-ink ${c}`} />
                <div className="h-2 w-4/5 rounded bg-ink" />
                <div className="h-2 w-2/5 rounded bg-ink/40" />
              </div>
            ))}
          </div>
          <div className="flex justify-around rounded-md border-[3px] border-ink bg-paper py-2">
            <BookOpen className="size-5" strokeWidth={3} />
            <Heart className="size-5" strokeWidth={3} />
            <History className="size-5" strokeWidth={3} />
          </div>
        </div>
      </div>
      <Badge tone="pink" className="absolute -right-3 -top-4 rotate-6 shadow-brutal">Neo-brutal</Badge>
      <Badge tone="mint" className="absolute -bottom-4 -left-3 -rotate-6 shadow-brutal">560+ sumber</Badge>
    </div>
  )
}

function Hero() {
  return (
    <section id="top" className="mx-auto grid max-w-6xl items-center gap-12 px-4 py-16 md:grid-cols-2 md:py-24">
      <div>
        <Badge tone="sun" className="mb-6 shadow-brutal">Android · Flutter · Open source</Badge>
        <h1 className="text-5xl font-bold leading-[1.02] tracking-tight sm:text-6xl lg:text-7xl">
          Baca komik &amp; novel,{' '}
          <span className="inline-block -rotate-1 border-[3px] border-ink bg-sun px-2 shadow-brutal">satu aplikasi.</span>
        </h1>
        <p className="mt-6 max-w-xl text-lg leading-relaxed sm:text-xl">
          Hub Reader bergaya Aniyomi/Mihon. Ambil konten langsung dari situs sumbernya di HP, tanpa server dan tanpa akun.
        </p>
        <div className="mt-8 flex flex-wrap gap-4">
          <Button href={RELEASE} size="lg">
            <Download className="size-5" strokeWidth={3} /> Unduh APK
          </Button>
          <Button href={REPO} size="lg" variant="outline">
            <Github className="size-5" strokeWidth={3} /> GitHub
          </Button>
        </div>
      </div>
      <PhoneMock />
    </section>
  )
}

function Stats() {
  const stats = [
    { v: '560+', l: 'Sumber komik', tone: 'bg-pink' },
    { v: '16', l: 'Bahasa', tone: 'bg-mint' },
    { v: '4', l: 'Tracker', tone: 'bg-sun' },
    { v: '0', l: 'Server', tone: 'bg-white' },
  ]
  return (
    <section className="mx-auto max-w-6xl px-4 pb-20">
      <div className="grid grid-cols-2 gap-5 md:grid-cols-4">
        {stats.map((s) => (
          <div key={s.l} className={`rounded-lg border-[3px] border-ink p-5 text-center shadow-brutal ${s.tone}`}>
            <div className="text-4xl font-bold sm:text-5xl">{s.v}</div>
            <div className="mt-1 font-mono text-sm font-bold uppercase">{s.l}</div>
          </div>
        ))}
      </div>
    </section>
  )
}

function Features() {
  return (
    <section id="fitur" className="mx-auto max-w-6xl scroll-mt-20 px-4 py-20">
      <h2 className="text-4xl font-bold sm:text-5xl">
        Fitur <span className="bg-mint px-2">lengkap</span>
      </h2>
      <p className="mt-3 max-w-2xl text-lg">Semua yang kamu butuhkan untuk membaca, tanpa ribet.</p>
      <div className="mt-10 grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
        {features.map(({ icon: Icon, tone, title, text }) => (
          <Card key={title} tone={tone}>
            <div className="mb-4 inline-flex rounded-md border-[3px] border-ink bg-white p-2">
              <Icon className="size-6" strokeWidth={2.5} />
            </div>
            <h3 className="text-xl font-bold">{title}</h3>
            <p className="mt-2 leading-relaxed">{text}</p>
          </Card>
        ))}
      </div>
    </section>
  )
}

function Steps() {
  return (
    <section id="cara" className="scroll-mt-20 border-y-[3px] border-ink bg-sun py-20">
      <div className="mx-auto max-w-6xl px-4">
        <h2 className="text-4xl font-bold sm:text-5xl">Pasang dalam 3 langkah</h2>
        <div className="mt-10 grid gap-6 md:grid-cols-3">
          {steps.map((s) => (
            <Card key={s.n} tone="white">
              <div className="font-mono text-5xl font-bold text-berry">{s.n}</div>
              <h3 className="mt-2 text-2xl font-bold">{s.title}</h3>
              <p className="mt-2 leading-relaxed">{s.text}</p>
            </Card>
          ))}
        </div>
        <div className="mt-10">
          <Button href={RELEASE} size="lg" variant="dark">
            <Download className="size-5" strokeWidth={3} /> Ke halaman rilis
          </Button>
        </div>
      </div>
    </section>
  )
}

function Faq() {
  return (
    <section id="faq" className="mx-auto max-w-3xl scroll-mt-20 px-4 py-20">
      <h2 className="mb-10 text-4xl font-bold sm:text-5xl">
        Sering <span className="bg-pink px-2">ditanya</span>
      </h2>
      <Accordion items={faqs} />
    </section>
  )
}

function Cta() {
  return (
    <section className="mx-auto max-w-6xl px-4 pb-20">
      <div className="rounded-xl border-[4px] border-ink bg-pink p-8 text-center shadow-brutal-lg sm:p-14">
        <h2 className="text-4xl font-bold sm:text-6xl">Siap membaca?</h2>
        <p className="mx-auto mt-4 max-w-xl text-lg">Gratis, open source, dan terus bertambah sumbernya.</p>
        <div className="mt-8 flex flex-wrap justify-center gap-4">
          <Button href={RELEASE} size="lg" variant="dark">
            <Download className="size-5" strokeWidth={3} /> Unduh versi terbaru
          </Button>
          <Button href={`${REPO}/issues`} size="lg" variant="outline">
            Laporkan masalah
          </Button>
        </div>
      </div>
    </section>
  )
}

function Footer() {
  return (
    <footer className="border-t-[3px] border-ink bg-ink py-8 text-paper">
      <div className="mx-auto flex max-w-6xl flex-col items-center justify-between gap-3 px-4 font-mono text-sm sm:flex-row">
        <span>© {new Date().getFullYear()} Hub Reader</span>
        <a href={REPO} className="font-bold underline decoration-sun decoration-2 underline-offset-4">
          github.com/Bayu-Pasifik/hub-reader
        </a>
      </div>
    </footer>
  )
}

export default function App() {
  return (
    <>
      <Nav />
      <main>
        <Hero />
        <Marquee items={marqueeItems} className="-rotate-1 scale-105" />
        <Stats />
        <Features />
        <Steps />
        <Faq />
        <Cta />
      </main>
      <Footer />
    </>
  )
}
