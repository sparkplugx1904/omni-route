# Route Planner (Multiroute)

**Fair Workload Balancing** untuk pembagian rute multi-tim: tim dengan jarak jauh mendapat kunjungan sedikit, tim dengan jarak dekat mendapat kunjungan banyak. Satu core C++17, dua kemasan:

- **🌐 Web app (utama)** — C++ di-compile ke WebAssembly; seluruh komputasi berjalan di browser (tanpa server, tanpa API key).
- **🖥️ CLI native C++** — untuk pemakaian skrip/batch, menghasilkan HTML peta Leaflet.

<p align="center">
  <a href="https://sparkplugx1904.github.io/route/?lang=en" target="_blank">
    <img src="https://img.shields.io/badge/TRY IT NOW-orange?style=for-the-badge&&logoColor=white&color=FF5500" alt="Route Planner"/>
  </a>
</p>

## 🌐 Web App

### Fitur

- **Cari titik via OSM Nominatim** (gratis), klik peta, paste batch koordinat, atau upload CSV.
- **Checklist 3 langkah** (titik → depot → kendaraan) yang mengunci tombol Hitung sampai lengkap, plus saran jumlah kendaraan otomatis.
- **6 mode pembagian rute** (lihat bagian Algoritma) + profil perjalanan driving/bike/foot.
- **Peta Leaflet**: marker bernomor, rute sepanjang jalan (polyline OSRM) atau garis lurus, marker depot S=Start/Finish, drag marker untuk memindahkan titik.
- **Panel hasil per tim**: urutan kunjungan, jarak per segmen, estimasi waktu (kecepatan profil + 5 menit/titik), badge keseimbangan (`ok` / `±%`), highlight tim (rute lain diredupkan 30%).
- **Share "lembar pengemudi"**: salin ke clipboard, unduh .txt, atau langsung kirim ke WhatsApp.
- **Sesi otomatis** tersimpan di localStorage (aman dari reload), export/import CSV titik.
- **Offline**: PWA (service worker + manifest), banner offline, fallback haversine×1.3 saat OSRM gagal / koneksi mati.
- **i18n 11 bahasa** (`?lang=` → localStorage → bahasa browser): en, id, es, zh, hi, ar, fr, de, pt, ru, ja.

### Quick Start (dev lokal)

```bash
npm install
npm run dev        # vite dev server → http://localhost:5173
npm run build      # build produksi ke dist/
npm run preview    # pratinjau build produksi
npm run deploy     # build + deploy ke Cloudflare Pages (project: multiroute)
```

Hasil build WASM (`public/wasm/route_planner_wasm.js/.wasm`) **sudah ter-commit**, jadi `npm run dev` langsung jalan tanpa Emscripten. CI rebuild-nya otomatis setiap push.

### Deploy

- **GitHub Pages** — otomatis via CI `.github/workflows/static.yml`: build WASM (emsdk) → build Vite → deploy `dist/`.
- **Cloudflare Pages** — `npm run deploy` (wrangler, project `multiroute`).

### Build WASM manual (opsional)

Untuk mengubah kode C++ di web app — butuh [Emscripten SDK](https://emscripten.org/docs/getting_started/downloads.html):

```bash
# Windows                            # Linux/macOS
set EMSDK=C:\emsdk                   export EMSDK=~/emsdk
wasm\build_wasm.bat                  wasm/build_wasm.sh
```

Skrip meng-compile `wasm/wasm_main.cpp` + core bersama (`src/`, `include/`, `third_party/`) dan menyalin artifact ke `public/wasm/`.

### Lapisan caching

| Lapisan | Isi | Lokasi |
|---|---|---|
| Matrix jarak (n×n km) | hashed SHA-256 (koordinat + profil) | IndexedDB `route-planner-cache` |
| Polyline per segmen | hashed SHA-256 (pasangan titik + profil) | IndexedDB |
| Cache disk (CLI native) | matrix binary | `.osrm_cache/` |

- Matrix di-fetch dengan **chunk 60 koordinat/request** ke `router.project-osrm.org` (publik, tanpa API key).
- Bila semua gagal → fallback **haversine × 1.3** via WASM (hasil tetap valid, estimasi jarak kurang akurat).
- Panduan Nominatim diterapkan: maks 1 request/detik, atribusi OSM.

## 🖥️ CLI Native C++

### Build & Run

```bat
:: Windows
build.bat
build\Release\route_planner.exe --csv locations.csv --start-name "Kantor Pusat" --start-lat -8.6507 --start-lon 115.2321 --teams 14
```

```bash
# Linux/Mac
chmod +x build.sh && ./build.sh
./build/route_planner --csv locations.csv --start-name "Kantor Pusat" --start-lat -8.6507 --start-lon 115.2321 --teams 14
```

### Options

```
route_planner [OPTIONS]

Required:
  --csv <file>              Path to CSV file with locations
  --start-name <name>       Depot/start location name
  --start-lat <lat>         Depot latitude
  --start-lon <lon>         Depot longitude

Optional:
  --teams <N>               Number of teams (default: 14)
  --mode <mode>             balanced | nearest | fuel-efficient |
                            equal-distance | compact | balanced-distance
  --output <file>           Output HTML file (default: routes_v6.html)
  --restarts <N>            Clustering restart attempts (default: 10)
  --profile <mode>          OSRM profile: driving/bike/foot (default: driving)
  --no-road-lines           Draw straight lines instead of road geometry
  --http-workers <N>        HTTP worker threads (default: 8)
  -h, --help                Print help
```

### CSV Format

Header fleksibel (case-insensitive) dengan 3 kolom:

```csv
location, latitude, longitude
Toko A, -8.540357, 115.322862
Toko B, -8.654217, 115.216231
```

Kolom nama yang dikenali: `location`, `lokasi`, `nama`, `name`, `sekolah`, `school`, `place`, `site`. Koordinat: `latitude`/`lat`, `longitude`/`lon`/`lng`. Contoh dataset ada di `samples/`.

## 📁 Struktur Proyek

```
route-planner/
├── index.html               # Entry web app (root Vite)
├── public/                  # Aset statis web (disalin utuh ke dist/)
│   ├── css/style.css
│   ├── js/                  # main, map, osrm, idb-cache, result-panel, upload,
│   │   │                    # search-provider, i18n + js/lang/*.js (11 bahasa)
│   │   └── wasm/worker-entry.js   # Web Worker pembungkus WASM
│   ├── wasm/                # Artifact hasil build (route_planner_wasm.js/.wasm)
│   ├── manifest.json        # PWA manifest
│   └── sw.js                # Service worker (cache-first app shell)
├── wasm/                    # Build Emscripten
│   ├── CMakeLists.txt       # Toolchain + flag + copy artifact → public/wasm/
│   ├── wasm_main.cpp        # C-ABI WASM (parse_csv, haversine_matrix_fill, compute_routes_wasm)
│   └── build_wasm.bat/.sh   # Skrip build lokal (emsdk)
├── src/                     # Core C++ (dipakai native & WASM) + main.cpp (CLI)
├── include/                 # Header C++ (types, utils, csv_parser, osrm_client,
│                            # tsp_solver, clustering, engine, map_builder)
├── third_party/             # Header-only: cxxopts, nlohmann/json, cpp-httplib
├── samples/                 # Dataset contoh/uji (CSV, area Bali)
├── docs/                    # Dokumen perencanaan (historis)
├── legacy-python/           # Versi Python pendahulu (v5, v6) — hanya referensi
├── CMakeLists.txt           # Build CLI native
├── build.sh / build.bat     # Skrip build CLI
├── package.json             # Vite + Wrangler (web app)
└── .github/workflows/static.yml   # CI: build WASM + deploy GitHub Pages
```

**Alur komputasi (sama di native & web):** load koordinat (depot = index 0) → matrix jarak jalan n×n → estimasi bobot α/β (mode balanced) → clustering sesuai mode → TSP closed tour per tim → rute & peta.

## 🧮 Algoritma

### Workload Balancing

```
Workload = α × Jarak(km) + β × Jumlah_Kunjungan
```

- α dan β **auto-tuned** dari karakteristik data (sampling 20 assignment acak), bukan hardcoded.
- Target beban per tim dihitung, lalu **greedy growth** + **local search** (swap antara tim berat↔ringan) meminimalkan variance antar tim; direstart beberapa kali, terbaik dipilih.

### 6 Mode Pembagian

| Mode | Strategi |
|---|---|
| `balanced` (default) | Adil beban kerja via α/β di atas |
| `nearest` | Assign tiap titik ke seed tim terdekat |
| `fuel-efficient` | Greedy minimalkan *penambahan* jarak total |
| `equal-distance` | Greedy jaga jarak antar tim seimbang (jumlah kunjungan boleh beda) |
| `compact` | K-means geografis (20 iterasi, centroid haversine) |
| `balanced-distance` | Hybrid: jarak & jumlah kunjungan diberatkan rata |

### TSP (rute dalam tim)

- **≤10 titik/tim**: Held-Karp DP eksak (O(n²·2ⁿ)).
- **>10 titik**: Nearest Neighbor + 2-opt (500 iterasi, early stop). Konstanta `CHRISTOFIDES_MAX=16` di `include/tsp_solver.hpp` adalah warisan versi Python lama — di C++ konstanta itu tidak dipakai; pilihan algoritma diatur `EXACT_TSP_MAX=10`.
- Hasil selalu **closed tour**: Depot → … → Depot, dan semua angka jarak **sudah termasuk pulang-pergi (PP)**. Order di-cache per (depot, set titik terurut).

Contoh 3 lokasi (A, B, C): `Depot → A → B → C → Depot`; jarak = d(0→A)+d(A→B)+d(B→C)+d(C→0) — segmen pulang ikut dihitung (aksi eksplisit di Held-Karp: `dp[full][j] + matrix[last][depot]`).

## ⚡ Kinerja

| Operasi | CLI native (150 titik, 14 tim) | Web (WASM) |
|---|---|---|
| Load CSV | <0.1s | parse via WASM di worker |
| Matrix OSRM (pertama) | 5–15s (jaringan) | sama, per chunk + progress |
| Matrix (cache) | <0.1s (disk) | instan (IndexedDB) |
| Clustering (10 restart) | 2–5s | di browser, worker terpisah |
| TSP per tim | <0.1s (DP ≤10 titik) | sama |
| Output | HTML string build | render Leaflet realtime |
| **Total (cached)** | **3–6s** | beberapa detik tergantung jaringan |

## 📝 License

MIT License — lihat [LICENSE](LICENSE).

## 🙏 Credits

- **OSRM** (Open Source Routing Machine) & **OpenStreetMap / Nominatim** — data rute & pencarian
- **Leaflet.js** — peta interaktif
- **cxxopts, nlohmann/json, cpp-httplib** — library header-only
- **Emscripten** — C++ → WebAssembly
- Versi Python pendahulu — lihat `legacy-python/`
