# Karakter Görselleri — Teslim Talimatı

Bu klasöre aşağıdaki dosya adlarıyla **PNG, şeffaf arka planlı** görselleri bırak. Ben onları
Godot projesine texture olarak bağlayıp mevcut SVG placeholder'ların yerine geçireceğim
(kitchen/queue render kodu zaten bu isimleri arayacak şekilde güncellenecek).

## Beklenen dosyalar

| Dosya adı | Karakter | Önerilen boyut |
|---|---|---|
| `chef.png` | Uzaylı aşçı (tam beden/bel üstü) | 900×1080 (oran ~5:6) |
| `cust_octo.png` | Ahtapot kafalı müşteri | 900×900 (kare) |
| `cust_pirate.png` | Korsan müşteri | 900×900 |
| `cust_cyclops.png` | Tek gözlü müşteri | 900×900 |
| `cust_tri_eye.png` | Üç gözlü müşteri | 900×900 |
| `cust_horned.png` | Boynuzlu müşteri | 900×900 |
| `cust_tentabeard.png` | Dokunaçlı sakallı müşteri | 900×900 |

- Arka plan **tamamen şeffaf** (alpha channel), tek karakter, ön/3-4 açıdan çekim, karakter
  kadrajın ortasında ve kenarlara taşmıyor (biraz boşluk bırak, ben Godot tarafında kırpabilirim).
- Işık yönü tutarlı olsun (hepsi aynı sahneden gibi dursun): yumuşak, sol-üstten gelen ana ışık.
- Stil: Sevimli-egzotik fantastik/uzaylı karakter tasarımı (bkz. proje temasi — "Yığın be Yığın"),
  gerçekçi ışık-gölge ve doku, ama komik/dost canlısı bir restoran oyunu havası (korkutucu değil).
- **Orijinal/özgün olmalı** — herhangi bir telifli marka/karakter/stok paketin birebir taklidi olmasın
  (bkz. proje dokümanındaki telif disiplini). AI aracına "in the style of X marka" gibi promptlar verme.

## Gemini için prompt taslakları

Gemini/Imagen **gerçek şeffaf PNG üretmiyor** — düz bir arka planla çıktı veriyor. Bu yüzden arka
planı sabit bir "chroma key" rengine (magenta) sabitliyoruz; PNG'leri teslim ettiğinde o rengi
otomatik şeffaflaştırıp Godot'a öyle ekleyeceğim. Gemini doğal cümle promptlarına virgüllü etiket
listelerinden daha iyi yanıt verdiği için her prompt tek bir akıcı paragraf.

Her prompta ekleyeceğin **ortak kapanış cümlesi** (stil/arka plan tutarlılığı için):
`The character is centered with some empty margin around it, photographed against a completely
flat, solid magenta (#FF00FF) background with no shadows, gradients, or texture on the background.
Soft, friendly studio lighting from the upper-left. Charming, whimsical creature-design style for
a cozy cooking mobile game — expressive and endearing, not scary. Clean single subject, no text,
no watermark, no logo.`

- **chef.png**: `A cheerful alien chef creature with pebbled green skin, wearing a tall white chef
  hat and a white apron over a round belly, big round friendly eyes, short stubby arms holding a
  wooden spoon, standing waist-up pose.`
- **cust_octo.png**: `A cute pastel-teal octopus-headed alien restaurant customer, big round
  friendly eyes, a few short tentacles draping down like hair, bust portrait.`
- **cust_pirate.png**: `A whimsical olive-green alien pirate customer wearing a tricorn hat and an
  eyepatch over one eye, the other eye big and expressive, small friendly grin, bust portrait.`
- **cust_cyclops.png**: `A round orange-skinned one-eyed alien customer with two small stubby
  horns, one big expressive eye, chubby friendly cheeks, bust portrait.`
- **cust_tri_eye.png**: `A smooth blue-skinned alien customer with three small round eyes arranged
  in a triangle on its face, rounded head, curious friendly expression, bust portrait.`
- **cust_horned.png**: `A green alien customer with two curved cream-colored horns, big dark round
  eyes, a small friendly fanged smile, bust portrait.`
- **cust_tentabeard.png**: `A purple alien customer with a beard made of several small dangling
  tentacles, big round friendly eyes, whimsical expression, bust portrait.`

Aynı sohbette art arda üretirsen (birini üretip devamında "şimdi de X ama aynı ışık/stil/arka
planla") stil tutarlılığı daha kolay kalır.

## Sonraki adım

Ürettiğin görselleri (magenta arka planlı, PNG/JPG fark etmez) bu klasöre `chef.png`,
`cust_octo.png` ... adlarıyla bırak, bana haber ver. Ben magenta'yı şeffaflaştırıp `main.gd`'deki
chef/queue render kodunu bu görselleri kullanacak şekilde güncelleyip Godot'ta test edeceğim.
