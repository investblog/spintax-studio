# Tanı sekmesi size ne söylüyor

O sekmedeki her satır **makinenin** hükmüdür ve JavaScript, PHP ya da Python gerçeklemesinden
alacağınız hükmün aynısıdır — tek bir ortak külliyata tutulan dört bağımsız makine. Studio'nun
şablonunuz hakkındaki görüşü değildir. Makine burada bir şeye hata diyorsa, ailedeki her makine de
ona hata der ve şablonunuz sunucunuzda bu penceredeki gibi davranır.

| ne yazıyor | kim söylüyor | ne demek |
|---|---|---|
| **hata** | makine | şablon göründüğü şeyi yapmayacak |
| **uyarı** | makine | işleniyor, ama büyük olasılıkla kastettiğiniz gibi değil |
| **Studio notu** | Studio | makine bir şey söylemedi ve yine de söylemeye değer: daire çizen bir ekleme, büyük-küçük harfi farklı bir hedef, bir denetim karakteri |

**Nerede** sütunu satır ve sütundur. Satıra tıklamak imleci oraya koyar.

> Aşağıdaki her örnek, program her derlendiğinde Studio'nun bu kopyasının getirdiği makineden
> geçer ve sağda tam olarak onun geri verdiği durur. Burada hiçbir şey hatırlanmış ya da tahmin
> edilmiş değildir; doğru olmaktan çıkan bir yanıt derlemeyi durdurur. Makinenin sürümü
> **Yardım**, **Hakkında** altındadır.

## Örnekler nasıl okunur

`→` oku şablonu makinenin geri verdiğinden ayırır. `⏎` bir çıktı içindeki satır sonudur, `(boş)`
hiçbir şey yazmadığı anlamına gelir ve `…` tümüyle gösterilemeyecek kadar uzun bir çıktıyı
imler. Çıktıdan sonra üç boşlukla ayrılmış metin bir nottur, yanıtın parçası değil.

Örneklerin hangi koşullarda koştuğu sınamalarda gizli değil buradadır — onlar olmadan bazı yanıtlar
yeniden üretilemez. En çok şablon kümesi önemlidir: yoksa
`#include "frag"` → `Parça` bu belgenin hiç söylemediği bir şeye dayanırdı.

```spx-fixture
locale: tr
seed: 7
empty: (boş)
include frag: Parça
include loop: #include "loop"
include Intro: Giriş
```

`seed` kurayı sabitler: onsuz bir seçim ya da bir karıştırma her seferinde başka türlü yanıt verir
ve denetlenecek bir şey kalmazdı.

**Yerel ayar burada `tr` ve iki şeye karar veriyor:** makinenin kaç sayı biçimi beklediğine ve
hangi biçimin hangi sayıya gittiğine. Türkçe ve İngilizce iki ister. Rusça, Ukraynaca, Belarusça,
Sırpça, Hırvatça ve Boşnakça üç ister. Yerel ayar, arayüzün dilinden değil, sağ yarımın üstündeki
seçiciden gelir.

---

## Ayraçlar

**İmleci bir ayracın üstüne koyun, yapı kendini bütün olarak gösterir:** nerede başladığını, nerede
bittiğini ve **ayırıcılarının her birini**. İç içe gruplar onunla birlikte yanmaz — kendi
ayırıcıları vardır ve onlar, imleç kendi ayraçlarının üstüne geldiğinde gelir. Düzenlediğiniz şeyin
nerede bittiğini görmenin en hızlı yolu budur, hele `}` iki ekran sağa gitmiş uzun bir satırda.

Ayırıcı yalnız `|` değildir. Bir karıştırmada `[a<br>|b]` iki tane taşır: makine `<br>` işaretini
**sonraki** parçanın önüne konmuş bir ayırıcı olarak okur ve vurgulama onu ötekilerle birlikte
gösterir, çünkü yapının kuruluşunun bir parçasıdır.

### `bracket.unclosed` — bir ayraç açılıp hiç kapatılmamış

```
bir fiyat {ucuz|pahalı  →  Bir fiyat {ucuz|pahalı
```

Makine nerede kapatmak istediğinizi tahmin etmez. Metin ayracıyla birlikte olduğu gibi kalır ve
seçim hiç gerçekleşmez.

### `bracket.mismatched` — başka türden bir ayraçla kapatılmış

```
bir fiyat {ucuz|pahalı]  →  Bir fiyat {ucuz|pahalı]
```

`{` işareti `}` bekler, `[` işareti `]` bekler. Kaşlı ayraçla kapatılan bir karıştırma karıştırma
değildir.

### `bracket.unexpected-closing` — açık hiçbir şey yokken kapatan bir ayraç

```
bir fiyat ucuz} ve hepsi  →  Bir fiyat ucuz} ve hepsi
```

Metin olarak orada kalır. Çoğunlukla bir düzenlemeden artakalmış bir ayraçtır.

---

## Tanımlar

### `set.malformed` — bu `#set` satırı kurala uymuyor

```
#set sehir = Ankara
%sehir% içinde  →  #set sehir = Ankara ⏎ %sehir% içinde
```

**Ad yüzde işaretlerinin arasına yazılır:** `#set %sehir% = Ankara`. En sık yapılan ilk yanlış
budur ve panele bir anda iki satır koyar — bozuk satırın kendisi ve «bu değişken hiçbir yerde
tanımlı değil», çünkü hiçbir tanım gerçekleşmedi ve `%sehir%` kimsenin değil.

Çıktıya bakın: başarısız yönerge metinde **yazıldığı gibi** kaldı. Makine onu yönerge olarak
okumadı, yani sıradan bir satırdır ve sonuca girer.

### `def.malformed` — bu `#def` satırı kurala uymuyor

```
#def sayfalar = {1|3}
%sayfalar%  →  #def sayfalar = 1 ⏎ %sayfalar%
```

Aynı kural ve aynı bedel. `#def`, `#set`ten yazılışıyla değil, değerin **ne zaman** açıldığıyla
ayrılır: `#set` onu her anımsatmada yeniden açar, `#def` işleme başına bir kez. Bir yazım yanlışı
size ikisine birden mal olur.

Ve dikkatle bakın: başarısız yönergedeki `{1|3}` **bir olasılık çekti**. Satır sıradan metne
dönüştü — ve sıradan metin, ayraçlarıyla birlikte sıradan metin gibi işlenir. Bozuk bir satır
kapatılmış değildir; yalnızca yönerge olmaktan çıkar.

### `definition.duplicate-name` — bu ad yukarıda zaten tanımlı

```
#set %x% = birinci
#set %x% = ikinci
%x%  →  Ikinci
```

Çalışır — **son** tanım kazanır — ama makine buna hata der: bir adın iki kez konduğu bir belge
çift anlamlı okunur ve bir ay sonra iki satırdan hangisinin canlı olduğunu hatırlamazsınız. Hata
**ikinci** tanımı gösterir; birincisi daha yukarıdadır.

### `def.include-in-value` — bir tanımın değeri içinde `#include`

```
#def %x% = #include "frag"
%x%  →  Parça
```

Bir değerin içindeki ekleme beklediğinizden başka bir anda açılır ve aile bunu yasaklar. `#include`
işaretini kendi satırına koyun.

---

## Değişkenler

### `variable.undefined` — bu değişken hiçbir yerde tanımlı değil

```
merhaba, %ad%  →  Merhaba, %ad%
```

Hata değil, uyarı: makine adı olduğu gibi yazar. Bu bilerekdir — değer dışarıdan, konak programdan
gelebilir. Studio'da bu tür değerleri Değişkenler sekmesinde, **Oturum değerleri** altında
verirsiniz.

**Bir tanımın değeri panelde düzenlenebilir.** Üst bölümde Değer sütununa gelin ve **F2**'ye basın
(ya da doğrudan yazmaya başlayın); **Enter** uygular, **Esc** vazgeçer. Düzenleme tek bir geri alma
adımında **belgeye** gider: `Ctrl+Z` onu geri koyar.

Ad ve tür (`#set` ya da `#def`) düzenlenemez — bu bir karardır, yarım kalmış bir köşe değil. Bir
hücreden ad değiştirmek belgedeki bütün anımsatmaları koparır, satırı silmek ise açıklamayı ve
girintiyi de birlikte götürür. İkisi de metne aittir, ne yaptığınızı gördüğünüz yere.

Tam olarak değer değişir. Girinti, fazladan boşluklar, addaki büyük-küçük harfler ve satır sonundaki
bir açıklama olduğu gibi kalır: `   #set  %Marka%   =   Acme   /# kuyruk #/` bir düzenlemeden
yalnız `Acme` bakımından farklı döner. Dosya git'tedir ve bir satırı yeniden biçimlendirmek orada
sizin değişikliğiniz olarak görünürdü.

**Geri çevirme, makinenin satırı başka türlü okuyacağı anlamına gelir.** Düzenleme sessizce
uygulanmaz: makine sonucu geri okur ve istenen şeyi söylemiyorsa belgeye dokunulmaz ve durum çubuğu
bunu söyler. Üç gerçek neden: değerdeki bir `/#` dosyanın geri kalanını yiyen bir açıklama açar,
bir satır sonu yönergeyi erken bitirir ve yönergenin **içindeki** bir açıklama satırı parça parça
düzenlenemez kılar — onu metinde düzenleyin.

**Bir değişkenin adı üzerinde iki hareket.** Paneldeki ad bir bağlantıdır, bir etiket değil:

- **ada tıklamak** imleci, belgenin o değişkeni kullandığı ilk yere götürür ve satır bir an yanar.
  Aynı sözcük bir açıklamanın içinde ya da bir `#include` hedefi olarak **sayılmaz** — panel sizi
  değişkenin gerçekten çalıştığı yere götürür.
- **Ctrl+tık** belgeye bir tanım yazar ve üzerinde grup düzenleyiciyi açar. Daha önce yazdığınız
  değer ilk olasılık olarak içeri girer:

```
#set %marka% = {Vulkan}
kumarhane %marka%  →  Kumarhane Vulkan
```

İkisi arasındaki fark, pencereyi kapatmaktan neyin sağ çıktığıdır. Bir oturum değeri çıkmaz:
dosyada yoktur, git'te yoktur ve ailedeki başka hiçbir makine onu görmez. Bir tanım çıkar ve bu
uyarıyı temelli susturan yalnızca bir tanımdır. Bir `Ctrl+Z` belgeyi geri alır.

**Bir oturum değeri önce şablondur, metin değil.** Makine konak programdan gelen her değere bunu
yapar ve önizlemenin sunucuyla örtüşmesi gerekir — dolayısıyla değer alanına yazılan `{ucuz|pahalı}`
bir seçim verir, o on üç karakteri değil. Metnin kendisini kastediyorsanız üçüncü sütunda **metin
olarak** kutusunu işaretleyin: o zaman kaşlı ayraçlar ve yüzde işaretleri karakter olarak kalır.

### `variable.self-reference` — tanım kendi kendini anıyor

```
#set %x% = a %x% b
%x%  →  A a a … %x% … b b b
```

Elli düzey, sonra duruş. Makine derinlik sınırına kadar açar ve durur, `%x%` işaretini ortada
bırakır. Döngü değildir ve istediğiniz şey de değildir.

Yukarıdaki `…` bu belgenin kısaltmasıdır, makinenin değil. Gerçek çıktı 207 karakterdir ve her
yanda elli yerine **elli bir** harf taşır: ellinci düzey durur ve değeri olduğu gibi bırakır,
değerin içinde de her birinden bir tane daha vardır.

### `variable.circular-reference` — tanımlar birbirini daire çizerek anıyor

```
#set %x% = %y%
#set %y% = %x%
%x%  →  %y%
```

Her yan tam **bir kez** açılır ve sonra durur: `%x%`, `%x%` değil `%y%` oldu. Makine daireyi
dolaşmak yerine çözer ve sağ kalan, dairedeki öteki addır — bir belgeye `%x% %y%` koyun, `%y% %x%`
verir, çift ters çevrilmiş olarak.

Panel, **daireyi kapatan her anımsatma için** bir satır çizer; daire için bir satır ya da tanım
başına bir satır değil. Daireyi iki kez anan bir tanım kendi satırında iki satır alır:
`#set %x% = %y% %y%` ile `#set %y% = %x%` üç hata eder, ikisi birinci satırda. Satırlar
birleştirilmez. Ve konum, gerçekten geçerli olan tanımın üstündedir: ad iki kez tanımlıysa bu
**sonuncusudur**.

---

## Eklemeler

### `#include` yalnızca satır başında çalışır

```
önce #include "frag" sonra  →  Önce #include "frag" sonra
```

```
#include "frag"  →  Parça
```

Hiçbir tanı yok ve asıl mesele de bu: satırın ortasındaki bir `#include` ekleme **değildir**.
Makine onu sıradan metin olarak okur ve bir şey söylemez, çünkü yakınılacak bir şey yoktur — metin
yazdınız, metin aldınız.

**Hedef ise bir satır aşağıda durabilir** ve bu, öteki yandan şaşırtır. Makinenin sözcük ile hedefi
arasında bıraktığı boşluk satır sonlarını da içerir, dolayısıyla bu bir eklemedir ve çalışır:

```spx-good
#include
"frag"  →  Parça
```

Aralarında boş satırlar da olabilir. Başka her şey olamaz: hedeften önce bir sözcük ya da ardından
boşluktan başka bir şey — ve bütünü yine metne döner. Düzenleyici hedefi kendi satırında renklendirir
ama hedef gelene dek sözcüğü sıradan bırakır: sonunu henüz görmediği bir yönerge sözü vermez.

### `include.unknown-target` — kümede bu adda hedef yok

```
#include "hicbiri"  →  (boş)
```

Hedefler, açık belgenin klasöründeki `.spintax` dosyalarıdır. Bilinmeyen bir hedef hiçliğe açılır —
paragraf bozulmak yerine yok olur, ki bunu gözden kaçırmak tam da bu yüzden kolaydır.

**Değişkenler sekmesinin üçüncü bir bölümü, Eklemeler, bu yüzden vardır.** Belgedeki her `#include`
işaretini ve her biri için kümenin hedefi bulundurup bulundurmadığını sıralar — geçiş başına bir
satır, yani iki kez anılan bir hedef iki satır eder. Bölüm yalnızca belgede ekleme varsa görünür.
Bir satıra tıklamak imleci o hedefi anan `#include` işaretine götürür.

İşaretin **üç** değeri vardır ve üçüncüsü önemlidir: «küme yok», «parça eksik» demek değildir,
«henüz bakılacak bir yer yok» demektir. Küme, belgenin yanındaki klasördür ve kaydedilmemiş bir
belgenin klasörü yoktur — ilk kayda kadar her hedef böyle imlenir. «EKSİK» yalnızca bir klasör
varken ve dosya gerçekten orada değilken görünür.

### `note.case-mismatch` — hedef var, ama başka büyük-küçük harfle

```
#include "intro"  →  (boş)
```

Kümede `Intro.spintax` vardır — ve makine yine de böyle bir hedef olmadığını söyler, Studio ise
büyük-küçük harf notunu ekler. Bunlar önemlidir: `intro` ile `Intro` ayrı hedeflerdir. Windows
dosyayı iki durumda da açardı; Studio'nun dosya sistemine değil kümeye bakmasının nedeni tam da
budur: yoksa önizleme aynı belge üzerinde sunucuyla çelişirdi.

### `note.cycle` — daire çizen bir ekleme

`loop.spintax` dosyası kendisi `#include "loop"` içeriyorsa:

```
#include "loop"  →  (boş)
```

Makine sonsuzluk yerine hiçbir şey koyar. Not, paragrafın neden yok olduğunu bilesiniz diye
oradadır.

Satır, baktığınız belgeye değil **`loop`** üzerine kesilmiştir — daire parçanındır ve tıklandığında
imleç oraya gider. Açık belgede hiçbir şey altı çizili değildir, çünkü yazdığınız satırda bir
yanlış yoktur.

---

## Sayı biçimleri

### `plural.arity` — yerel ayarın istediği kadar biçim yok

```
#set %n% = 5
%n% {plural %n%: nesne|nesneler|nesneleri}  →  5 ｛plural 5: nesne|nesneler|nesneleri｝
```

**Boşluk değil — makine yapının tamamını yazar**, kaşlı ayraçlar geniş `｛｝` ile değiştirilmiş
olarak. «Bunu gördüm ve uygulayamadım» demenin yolu budur. Buna göze batmaz diyen olmaz ve iyi ki
öyle: sessizce yok olan bir paragrafı bulmak daha uzun sürerdi.

Türkçe iki biçim ister, Rusça üç. Bu belgenin yerel ayarı altında doğrusu
`{plural %n%: nesne|nesneler}`.

**Boşluk başka bir nedenden gelir ve ikisini karıştırmak kolaydır.** Yalnızca kaç biçim taşıdıkları
bakımından ayrılan şu ikisini karşılaştırın:

```
{plural %n%: nesne|nesneler}  →  (boş)   iki biçim: Türkçe için doğru
{plural %n%: nesne|nesneler|nesneleri}  →  (boş)   üç biçim: Türkçe için yanlış
```

İkisi de hiçbir şey yazmaz ve panel onlara başka türlü davranır: birincisi yalnız
`variable.undefined` çeker, ikincisi ayrıca `plural.arity` çeker. Yani **boşluk, biçim sayısı
yanlışının işareti değildir** — burada `%n%` tanımlı olmadığından gelir ve makine biçimleri
saymadan önce sayıyı denetler, dolayısıyla biçim sayısı sorusu ortaya çıkmadan durur.

Bu maddenin başındaki örnek `%n%` değişkenini bu yüzden önce tanımlar. Onsuz çıktı, biçim sayısı ne
olursa olsun boş kalırdı ve sayı hakkında hiçbir şey göstermezdi.

Panel ile çıktı burada ayrı soruları yanıtlar ve bu bir çelişki değildir: satırı, metindeki
biçimleri sayan ve sayıyla ilgilenmeyen **denetim** koyar; boşluğu ise kendi sırası olan **işleme**
verir. Sayıya bir rakam verin, ilk örnekteki gibi, ve biçim sayısının gerçekte ne yaptığını
görürsünüz.

### `plural.count-macro` — sayı bir `#set`ten geliyor, o da her anımsatmada yeniden çekiyor

```
#set %n% = {1|2}
%n% {plural %n%: nesne|nesneler}  →  1
```

Neyin sağ kaldığına bakın: **sayı yazıldı, ad yazılmadı.** Biçim seçilirken sayının sayı olması
gerekir ve değeri kendisi bir seçim olan bir `#set` hiçbir zaman sayı olmaz — makine değeri
**işlemeden** yerine koyar, dolayısıyla sayı yerine harfi harfine `{1|2}` metni düşer. Sayı ile
biçim çelişemez; makine bunun yerine sözcüğü düşürür.

`#def` başka türlü davranır ve değerini işleme başına bir kez açar, böylece sayı yerine bir sayı
gelir:

```
#def %n% = {1|2}
%n% {plural %n%: nesne|nesneler}  →  1 nesne
```

Onun için panelde hiç satır yoktur. Kural buradan gelir: sayıyı düz bir rakam ya da bir `#def`
yapın, asla `#set` değil.

### `plural.nested-brackets` — biçimlerin içinde ayraçlar

```
{plural %n%: {nesne|şey}|nesneler}  →  ｛plural %n%: ｛nesne|şey｝|nesneler｝
```

Biçimler düz metindir. İçlerindeki bir seçim açılmaz ve onun yerine yapının tamamı geniş ayraçlar
içinde yazılır.

---

## Karıştırmalar

### `permutation.unknown-key` — ayarda bilinmeyen anahtar

```
[<foo=1>a|b|c]  →  Bfoo=1cfoo=1a
```

Bilinen anahtarlar `minsize`, `maxsize`, `sep` ve `lastsep`'tir. Bilinmeyen biri ayar değildir — ve
blokta tek başınaysa bloğun tamamı hiç ayar değildir: parçalar arasındaki ayırıcıya dönüşür, ki
çıktının gösterdiği de budur.

**Yanında gerçek bir anahtar varsa sonuç bambaşkadır** ve asıl olası yanlış budur — birkaç
anahtardan biri yanlış yazılmıştır:

```
[<sep=", ";foo=1>a|b|c]  →  B, c, a
```

Blok bir ayardır, `sep` uygulanır, bilinmeyen anahtar öylece düşürülür ve panel iki durumda da aynı
şeyi söyler. Yani tanı size bir anahtarın anlaşılmadığını söyler; sonra ne olduğunu söylemez. Onun
için çıktıyı okuyun.

### `permutation.minsize-not-integer` — minsize tam sayı değil

```
[<minsize=iki>a|b|c]  →  B c a
```

Sayı olmayan bir değer sınırıyla birlikte düşer ve varsayılan geçerli olur — yani bütün parçalar.

### `permutation.maxsize-not-integer` — maxsize tam sayı değil

```
[<maxsize=cok>a|b|c]  →  B c a
```

Öteki uçtan tam olarak aynısı: üst sınır yok olur ve çıktı yine her parçayı taşır.

---

## Gösterecek bir şeyi olmayan Studio notları

Aşağıdaki üç not bu belgede bir örnekle gösterilemez ve nedeni her seferinde başkadır ve
söylenmiştir. Yine de maddeleri vardır: yardım, panelin gösterebileceği **her** satıra bir yanıt
borçludur, yoksa paneldeki bir satır hiçbir yere götürmez.

### `note.raw-sentinel` — metinde bir denetim karakteri

U+E000–U+E005 karakterleri makinenin kendi imlemesi için kullandığı karakterlerdir ve makine onları
çözümlemeden önce **kaldırır**. Şablonunuza girmişlerse — çoğunlukla başka bir düzenleyiciden
yapıştırılarak — Studio bunu söyler: ne önizleme ne de sunucu onları gösterecektir.

Burada bilerek örnek yok: o karakterler görünmezdir ve onları taşıyan bir satır boş görünürdü.
Görülecek bir şey olmazdı.

### `note.unknown-target` — küme boş, kıyaslanacak bir şey yok

Belgenin yanındaki küme **boş** olduğunda görünür: bundan başka tek bir şablon bile yok. Hedefi
kıyaslayacak bir şey olmadığından Studio «böyle bir hedef yok» demez — yanıt veremeyeceğini söyler.
O klasöre tek bir şablon koyun, not yerini esasa yanıt veren olağan `include.unknown-target`
iletisine bırakır.

Hiç kaydedilmemiş bir belgenin **hiç** kümesi yoktur ve bu üçüncü bir durumdur, bu değil: eklemeler
o zaman çıktıda harfi harfine kalır ve panel onlar hakkında bir şey söylemez. Belgeyi kaydedin,
çalışmaya başlarlar.

Burada yapısı gereği örnek yok: bu belgenin kümesi yukarıda bildirilmiştir ve boş değildir.

### `note.too-deep` — eklemeler çok derin iç içe

Makine iç içe `#include` işaretlerinin yirminci düzeyinde durur ve altına bir şey koymaz. Sınır
ailenindir: JavaScript, PHP ve Python makineleri de aynısını yapar, dolayısıyla ona çarpan bir
belge her yerde aynı davranır.

Burada boyutu yüzünden örnek yok: bir tane göstermek yirmi bir dosya isterdi.

---

## Her dilde bir sessizlik: kısaltmalar

### Bir kısaltma sonraki sözcüğü küçük bırakır

```
Dr. fiyatlarımız düşük  →  Dr. fiyatlarımız düşük
Xyz. fiyatlarımız düşük  →  Xyz. Fiyatlarımız düşük
```

Bir sözcük bakımından ayrılan iki satır ve her birinin ikinci sözcüğü size kuralı veriyor: `Dr.`
sonrasında cümle küçük kalır, `Xyz.` sonrasında büyütülür. Makine noktadan sonra büyütür — bildiği
bir kısaltmadan sonra ve `e.g.` ya da `U.S.` biçiminde olan her şeyden sonra dışında. Sessizdir:
tanı yok, uyarı yok ve fark etmenin tek yolu çıktıyı okumaktır.

**Liste Türkçe değildir, İngilizce de değildir.** 46 girdisi vardır ve 29'u Rusçadır:

| | |
|---|---|
| Latin | `etc vs mr mrs ms dr prof sr jr inc ltd co corp no st ave blvd` |
| Kiril | `соц эл см ср ст ул пр пер г р руб коп тыс млн млрд трлн доп напр прим изд обл респ стр табл рис мин макс тел факс` |

İki yarım da **her** yerel ayarda geçerlidir — kural hangi dili ayarladığınızı hiç sormaz. Yani
`руб.` Türkçe bir belgede sonraki sözcüğü korur ve `Dr.` Rusça bir belgede korur.

Türkçe metin için sonuç basit ve rahatsız edicidir: her gün yazdığınız kısaltmalardan yalnızca
`vs.`, `Dr.`, `Prof.` ve `No.` listededir, çünkü Latin yarısıyla çakışırlar. `vb.`, `sf.` ve `Sn.`
listede yoktur ve bir cümleyi bitirir. Dil kılavuzu ayrıca Türkçeye özgü, ölçülmüş bir sessizlik
daha taşır: cümle başındaki `i` harfi `İ` değil `I` olur.

---

## Doğru biçim neye benzer

```spx-good
bir fiyat {ucuz|pahalı}  →  Bir fiyat ucuz
```

```spx-good
[<minsize=2;sep=", ">a|b|c]  →  C, b
```

```spx-good
#set %vip% = 1
{?vip?size|herkese}  →  Size
```

```spx-good
#set %n% = 5
%n% {plural %n%: ürün|ürünler}  →  5 ürünler
```

```spx-good
önce /# bir not #/ sonra  →  Önce sonra
```

Beş yapı, beş temiz satır: bir seçim, ayarlı bir karıştırma, bir koşul, önünde sayı bulunan bir
sayı biçimi ve bir açıklama. Hiçbiri panele bir şey koymaz.

---

## Sık sorulanlar

**Paragraf neden öylece yok oldu?**
İki sık neden, ikisi de yukarıda: bilinmeyen bir `#include` hedefi ve daire çizen bir ekleme. İkisi
de hiçbir şey yazmaz. İlk akla gelen üçüncüsü — yanlış sayıda biçim — hiçbir şey yazmamak
**değildir**: makine yapının tamamını geniş ayraçlar `｛｝` içinde yazar. Oradaki boşluk, biçim
sayısından değil, sayı olmayan bir sayımdan gelir.

**Türkçe harf taşıyan değişken adım neden çalışmıyor?**
Adlar Latin harflerinden, rakamlardan ve alt çizgiden oluşur. `%şehir%` hiç değişken anımsatması
değildir — makine onu metin olarak okur ve bir şey söylemez, çünkü ona göre bildirilecek bir şey
yoktur:

```
merhaba %şehir% ve %ad%  →  Merhaba %şehir% ve %ad%
```

İkisi de değişmeden geçti ve tuzak burada: yalnızca ikincisi panelde bir satır çekti. Birincisi
sessizdir, dolayısıyla hiçbir şey size onun asla yerine konmayacağını söylemez. Adını değiştirin.
**Değerde** ise Türkçe harfler hiç sorun çıkarmaz.

**Aynı hata neden iki kez gösteriliyor?**
Bir tanım dairesi, onu kapatan her anımsatma için bir satır çeker — bakılacak iki yer, bazen üç.
Bunlar kopya değildir ve birleştirilmezler.

**Panel hata diyor ama çıktı doğru görünüyor. Hangisi?**
İkisi de. Bu, iki kez tanımlanmış bir adda olur: işleme doğrudur — son değer kazanır — ve belge
çift anlamlıdır. Hüküm belge hakkındadır, bu tek çıktı hakkında değil.

**Yerel ayarı değiştirdim ve belge kırmızıya döndü.**
Yerel ayar işini yapıyor. Tanıtım belgesi İngilizcedir ve sayı biçimleri iki tane taşır; yerel
ayarı Rusçaya alın, o iki biçim bir sayı hatasına dönüşür, çünkü Rusça üç ister. Türkçe de
İngilizce gibi iki ister, bu yüzden `tr` altında tanıtım belgesi sakin kalır. Yerel ayar
**belgeye** aittir; Studio'nun arayüz dilini değiştirdiğinizde onu değiştirmemesinin nedeni budur.

**Önizleme, sunucumun üreteceğiyle örtüşür mü?**
Aynı makine, aynı sürüm, aynı yerel ayar ve aynı değerlerle — evet, tam olarak; önizlemenin
yaklaşık bir şey değil gerçek `spintax-win` çalıştırmasının nedeni de budur. Ailenin **başka** bir
makinesiyle — JavaScript, PHP ya da Python olanıyla — hüküm ve şablonun verebileceği metinler
kümesi taşınır, ama belirli bir tohumun hangisini çektiği taşınmaz. Tam o çekilişi yinelemeyi aile
söz vermez.
