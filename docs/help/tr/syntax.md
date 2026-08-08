# Dil, yapı yapı

Şablon, içinde birkaç işaretli yer bulunan sıradan metindir. İşaretli olmayan her şey olduğu gibi
çıkar; bir şablonun çok sayıda metin üretebilmesini sağlayan işaretlerdir.

Altı tanedirler ve dilin tamamı budur: seçenekler arasında bir **seçim**, birkaç parçanın
**karıştırılması**, bir kez tanımlayıp adıyla kullandığınız bir **makro**, bir **koşul**, doğru
sözcük biçimini alan bir **sayım** ve başka bir şablonu içeri getiren bir **ekleme**. Açıklamalar,
hiçbir şey üretmeyen yedinci bir işarettir.

> Aşağıdaki her örnek, program her derlendiğinde Studio'nun bu kopyasının getirdiği makineden
> geçer ve sağda tam olarak onun geri verdiği durur. Burada hiçbir şey hatırlanmış ya da tahmin
> edilmiş değildir; doğru olmaktan çıkan bir yanıt derlemeyi durdurur. Makinenin sürümü
> **Yardım**, **Hakkında** altındadır.

Bu yardımdaki öteki belge, **Tanı sekmesi size ne söylüyor**, ters gidenleri anlatır. Bu belge,
hiçbir şey ters gitmediğinde yapıların ne yaptığını anlatır — bir şablonun şaşırtıcı bir şey yaptığı
ve hiçbir şeyin bunu bildirmediği birkaç yer de dahil.

## Örnekler nasıl okunur

`→` oku şablonu makinenin geri verdiğinden ayırır. `(boş)`, hiçbir şey yazmadığı anlamına gelir.
Çıktıdan sonra üç boşlukla ayrılmış metin bir nottur, yanıtın parçası değil.

Koşullar varsayılmak yerine belirtilmiştir, çünkü onlar olmadan aşağıdaki yanıtların yarısı yeniden
üretilemez:

```spx-fixture
locale: tr
seed: 7
empty: (boş)
include intro: {Acme|Globex} şirketine hoş geldiniz.
include shout: %marka% burada.
```

`seed` kurayı sabitler. İçinde seçim bulunan bir şablonun tek yanıtı yoktur, dolayısıyla tohumsuz
bir örnek her geçişte başka bir şey yazardı ve denetlenecek bir şey kalmazdı. Pencerede bu, sağ
yarımın üstündeki **seed** kutusudur; işaretleyin, yanında bir sayı alanı belirir ve siz
çalışırken önizleme durur.

`locale` sayı biçimlerini belirler ve arayüzün dili değil, sağ yarımın üstündeki seçicidir. Türkçe
ve İngilizce iki biçim ister; Rusça, Ukraynaca, Belarusça, Sırpça, Hırvatça ve Boşnakça üç ister.

## Seçimler

Aralarında `|` bulunan kaşlı ayraçlar: makine **birini** alır.

```spx-good
{Küçük|Büyük} bir oda.  →  Küçük bir oda.
```

Çekiliş rastgeledir, bu yüzden aynı şablon başka bir geçişte `Büyük bir oda.` verir. Seçimin
kendisi çevresindeki metne dokunmaz — bu belgenin sonuna doğru anlatılan son rötuş yine de ona
uzansa bile.

### İç içelik

Bir seçim başka bir seçim içerebilir, istenen derinlikte.

```spx-good
Acme {Pro {Plus|Max}|Lite}  →  Acme Pro Plus
```

İçteki seçim yalnızca dıştaki onun bulunduğu dalı aldığında yapılır: `Lite` çıkarsa `Plus|Max` hiç
sorulmaz — ve ölçülebilir biçimde, ona rastgele bir sayı bile sorulmaz.

### Boş bir olasılık

Bir olasılık boş olabilir. Bir şeyin yalnızca zaman zaman görünmesini sağlamanın olağan yolu budur.

```spx-good
{|Çok }büyük bir oda.  →  Büyük bir oda.
```

Boşluğu olasılığın içine yazmak, `{|Çok } ` yerine `{|Çok }`, alışkanlıktır, kural değil: son rötuş
çift boşluğu her hâlükârda tekleştirir.

## Karıştırmalar

Köşeli ayraçlar birkaç parça alır, kaç tane olacağını seçer, onları rastgele sıraya dizer ve
birleştirir.

```spx-good
[kırmızı|yeşil|mavi]  →  Yeşil mavi kırmızı
```

Kendi hâline bırakılırsa hepsini alır ve tek boşlukla birleştirir. Bir karıştırmayla ilgili başka
her şey, açan ayracın hemen ardındaki bir `<…>` bloğunda ayarlanır.

### Ayırıcı

```spx-good
[<, >kırmızı|yeşil|mavi]  →  Yeşil, mavi, kırmızı
```

Bir `<…>` bloğu, **bir ayar adlandırmadıkça** ayırıcının kendisidir: `sep`, `lastsep`, `minsize`
veya `maxsize`'dan biri, kendi başına bir sözcük olarak ve ardında bir `=` ile. O konumdaki başka
her şey ayırıcıdır, ne kadar ayara benzerse benzesin — `=` işareti olmayan bir anahtar:

```spx-good
[<maxsize 2>kırmızı|yeşil|mavi]  →  Yeşilmaxsize 2mavimaxsize 2kırmızı
```

ya da önüne bir şey yapışmış bir anahtar:

```
[<xmaxsize=1>kırmızı|yeşil|mavi]  →  Yeşilxmaxsize=1mavixmaxsize=1kırmızı
```

İkincisi ikinci bir bakışı hak eder: panel `xmaxsize`'a bilinmeyen anahtar **diyor** ve makine yine
de bloğun tamamını parçaların arasına yazıyor. Tanı ile çıktı ayrı soruları yanıtlıyor.

İki ayrı ayırıcı istediğinizde ayarları açıkça yazın:

```spx-good
[<sep=", ";lastsep=" ve ">kırmızı|yeşil|mavi]  →  Yeşil, mavi ve kırmızı
```

`sep` parçaların arasına, `lastsep` sonuncudan önce girer.

### Kaç tane

```spx-good
[<minsize=2;maxsize=2>kırmızı|yeşil|mavi]  →  Yeşil mavi
```

`minsize` taban, `maxsize` tavandır; aradaki sayı da sıra gibi rastgeledir. Eşit değerler tam
olarak o kadarını alır. **İkisi de yoksa hepsi — ama yalnız `maxsize` varsa taban bire iner**, ki
bu şaşırtır:

```spx-good
[<maxsize=3>a|b|c]  →  C
```

Üç parça, üç tavan ve bir tanesi çıktı. «Hepsi, en çok üç» demek istiyorsanız `minsize` de yazın.
Parça sayısını aşan bir `maxsize` sessizce o sayıya indirilir. `maxsize`'ı aşan bir `minsize` tek
söz edilmeden kabul edilir ve taban kazanır: tavan ona yükseltilir, tersi değil:

```spx-good
[<minsize=3;maxsize=1>kırmızı|yeşil|mavi]  →  Yeşil mavi kırmızı
```

### İki parça arasında bir ayırıcı

İki parçanın **arasına** yazılan bir `<…>`, o çiftin ayırıcısıdır.

```spx-good
[kırmızı|yeşil<ve>|mavi]  →  Yeşil ve mavi kırmızı
```

Kendisinden **sonraki** parçaya aittir ve karıştırma boyunca onunla birlikte yolculuk eder; bu
yüzden çıktıda sabit bir yerde değil, o parça nereye düşerse orada belirir. **Son** parçadan
sonraki bir `<…>` hiç ayırıcı değildir ve metin olarak yazılır:

```spx-good
[kırmızı|yeşil|mavi<ve>]  →  Yeşil mavi<ve> kırmızı
```

## Makrolar

`#set` bir metin parçasına ad verir. Ad `%ad%` biçiminde kullanılır ve yönerge kendi satırındaki ilk
şey olmalıdır — önünde boşluk ve sekme olabilir, başka bir şey olamaz.

```spx-good
#set %sehir% = Ankara
%sehir% uçuşu.  →  Ankara uçuşu.
```

Adlar Latin harfleri, rakamlar ve `_` işaretinden oluşur. Başka bir alfabedeki bir ad, ad değildir;
öteki belge bunu `set.malformed` altında anlatır. Türkçeye özgü harfler bu yüzden bir ada girmez;
bir değere girer.

### `#set` yeniden çeker, `#def` bir kez çeker

İkisi arasındaki bütün fark budur ve yalnızca değer bir seçim içerdiğinde görünür.

```spx-good
#set %secim% = {A|B}
%secim% %secim% %secim%  →  A A B
```

```spx-good
#def %secim% = {A|B}
%secim% %secim% %secim%  →  A A A
```

İki örnek de aynı tohum altında koştu. `#set` şablonu saklar ve her kullanımda yeniden çeker;
`#def` bir kez çeker ve yanıtı tutar. Kendisiyle uyuşması gereken bir şey için — bir marka, bir
şehir, bir ad, bir sayı — `#def` kullanın, çeşitlilik için `#set`.

Tek bir tohum ikisini ayırt etmeye yetmez: `#set`in rastlantıyla üç kez aynı olasılığı çektiği
tohumlar vardır ve ikisi aynı görünür. Tek bir önizlemeden bir tanımın çalışmadığı sonucunu
çıkarmadan önce bilmekte yarar var.

## Koşullar

`{?ad?ise|değilse}` bir makronun değeri olup olmadığını sorar.

```spx-good
#set %n% = 5
{?n?elimizde %n% var|henüz yok}  →  Elimizde 5 var
```

`değilse` yarısı yazılmayabilir — yanıt hayırsa `{?ad?ise}` hiçbir şey yazmaz. Bir `!` soruyu ters
çevirir:

```spx-good
#set %vip% = 1
{?!vip?yabancı|dost}  →  Dost
```

Değeri olmak, **boşluk olmayan en az bir karakteri olmak** demektir. Hiçbir şeye ya da yalnızca
boşluklara ayarlanmış bir makro değersiz sayılır.

Bir koşulun adı bir harf ya da `_` ile **başlamalıdır**; bu, bir makroya göre daha sıkıdır — ve
sessizlikler bölümü, rakamla başlayan bir adın neye dönüştüğünü söyler.

## Sayım

`{plural %n%: …}` bir sayıya uyan sözcük biçimini alır.

```spx-good
#def %n% = 1
%n% {plural %n%: dosya|dosyalar}  →  1 dosya
```

```spx-good
#def %n% = 5
%n% {plural %n%: dosya|dosyalar}  →  5 dosyalar
```

Sayı burada bilerek bir `#def`tir, `#set` değil; kural akılda tutmaya değer: **sayıyı düz bir
rakam ya da bir `#def` yapın, asla `#set` değil.** Bir `#set`ten sayı yerine ulaşan şey saklanan
METİNdir, `5` değil `{5|5}` — yani sayı değildir, dolayısıyla yapının tamamı hiçbir şey üretmez ve
panel `plural.count-macro` der. Sayı ile biçim birbiriyle çelişemez: bunun yerine sözcük yok olur.

```
#set %n% = {5|5}
%n% {plural %n%: dosya|dosyalar}  →  5
```

Kaç biçim olduğuna siz değil yerel ayar karar verir: `tr` altında iki, `ru` altında üç. Yanlış sayı
panelin bildirdiği bir hatadır (`plural.arity`) ve makine o zaman yapının tamamını, kaşlı ayraçlar
geniş `｛｝` ile değiştirilmiş olarak geri yazar; böylece çıktı sanılmaz.

## Parçalar

`#include "ad"` o noktaya başka bir şablon koyar ve yönerge kendi satırındaki ilk şey olmalıdır —
burada da önünde boşluk ve sekme olabilir.

```spx-good
#include "intro"  →  Acme şirketine hoş geldiniz.
```

Parça kendi şablonu olarak işlenir, bu yüzden içindeki bir seçim yeniden yapılır: `intro`,
`{Acme|Globex}` içerir ve biri ya da öteki ile yanıt verir.

Ad **tam olarak** karşılaştırılır. `Intro` ile `intro` iki ayrı parçadır ve Windows'ta bunu
karıştırmak kolaydır, çünkü dosya sistemi umursamaz. Eksik bir hedef hiçbir şey olarak işlenir ve
panel `include.unknown-target` der; yalnızca büyük-küçük harfte ayrılan bir hedef, muhtemelen
kastettiğiniz adı söyleyen bir Studio notu alır.

### Bir parça sizin makrolarınızı görmez

Kendi şablonu olarak işlenir: oturumun değerlerine sahiptir, ama onu içeri getiren belgenin `#set`
ve `#def` tanımlarına değil.

```
#set %marka% = Acme
#include "shout"  →  %marka% burada.
```

`shout`, `%marka% burada.` demektir ve adın parçanın kendi içinde tanımlanması gerekir. Bu bir
sessizlik değildir — panel `variable.undefined` diyor — ama bunu o dosyanın 1. satırında
**`shout`** için söyler ve baktığınız belgede hiçbir dalgalı çizgi belirmez, çünkü konum başka bir
tampona aittir. Bir uyarı yazmadığınız bir satırla ilgiliymiş gibi göründüğünde **Dosya** sütununu
okuyun.

## Açıklamalar

`/# … #/` bir açıklamadır: işaretlerin arasındaki her şey, başka herhangi bir şeyden önce
kaldırılır.

```spx-good
taslak /# emin değilim #/ hazır  →  Taslak hazır
```

Açıklamalar iç içe geçmez. İlk `#/` açıklamayı kapatır, öncesinde ne olursa olsun; bu yüzden
kendisi `#/` içeren bir metnin çevresine sarılmış bir açıklama, göründüğünden önce biter.

## Makinenin sonda düzelttikleri

Çıktı, yapıların ürettiği metnin tam olarak kendisi değildir. Sonda ona birkaç şey olur; ikisiyle
her gün karşılaşırsınız.

Her cümlenin ilk harfi büyütülür:

```spx-good
bir. iki. üç.  →  Bir. Iki. Üç.
```

Bu yüzden bu yardımdaki örnekler, şablonda küçük harf varken çok kez büyük harfle yanıt verir.
Makinenin bildiği bir kısaltmadan sonraki nokta bir cümleyi bitirmez; `e.g.` ya da `U.S.` biçiminde
olan bir şey de bitirmez — **Latin harfleriyle**, ki bu gerçek bir sınırdır, bir kaçamak değil:
«bir sözcüğün ortasında mıyız» denetimi bir ASCII denetimidir.

```spx-good
vs. fiyatlarımız düşük  →  vs. fiyatlarımız düşük
```

```spx-good
Dr. fiyatlarımız düşük  →  Dr. fiyatlarımız düşük
```

Başka her sözcük bir cümleyi bitirir, ne kadar kısa olursa olsun — uzunluğun bununla ilgisi yoktur:

```spx-good
Xyz. fiyatlarımız düşük  →  Xyz. Fiyatlarımız düşük
```

Makinenin bildiği liste 46 girdilidir, **29'u Kiril**, ve öteki belge onu **Her dilde bir
sessizlik** başlığı altında baştan sona gezer. Türkçe metin için asıl önemli olan aşağıda,
sessizliklerdedir: liste Türkçeye göre ayarlanmamıştır.

Her günkü ikinci şey, boşluk dizilerinin teke inmesidir. Boş bir olasılığı çevresindeki boşlukları
saymadan bırakabilmenizi sağlayan budur.

Gerisi bir solukta: `,;:!?.` önündeki bir boşluk atılır ve arkasına bir tane konur; çıktının tamamı
kenarlarından budanır; büyük harf yalnızca noktadan sonra değil, satır sonundan ve blok etiketinden
sonra da gelir; ve şemalı adresler, e-posta adresleri, çıplak alan adları ve ondalık sayılar
korunur ve tam olarak yazıldıkları gibi çıkar.

Bunların sonuncusu yukarıdaki kısaltmalarla aynı ASCII sınırını taşır. Çıplak bir alan adı Latin
harfleriyle yazılmışsa korunur; `сайт.рф` korunmaz ve son rötuş içine bir boşluk ve bir büyük harf
sokar.

```spx-good
merhaba , dünya  →  Merhaba, dünya
```

```spx-good
bir.iki  →  bir.iki
```

## Sessizlikler

Aşağıdaki her durum işlenir, göründüğünden başka bir şey üretir ve **hiçbir tanı** doğurmaz.
Buraya toplanmışlardır, çünkü pencerede başka hiçbir şey onlardan hiç söz etmeyecek.

**Noktalı `i` büyütülürken noktasını yitirir.** Türkçe yazanların ilk çarpacağı sessizlik budur ve
en görünür olanıdır: makinenin cümle başındaki büyütmesi `i` harfini `İ` değil `I` yapar, çünkü
kural ASCII'nin kuralıdır ve yerel ayarı hiç sormaz.

```spx-good
işte bu bir cümle. işte diğeri  →  Işte bu bir cümle. Işte diğeri
```

Yukarıdaki `bir. iki. üç.` örneğinde de aynısı görülür: `iki`, `İki` değil `Iki` olur. Hiçbir tanı
bunu söylemez, çünkü makine için ortada bir yanlış yoktur. Cümleyi başka bir harfle başlatmaktan
ya da büyük harfi kendiniz yazmaktan başka çare yoktur.

**Türkçe kısaltmalar makinenin listesinde değildir.** Yalnızca listenin Latin yarısıyla çakışan
sözcükler korunur — yukarıdaki `vs.`, `Dr.` ve `Prof.` ile ayrıca `No.` —, buna karşılık `vb.`,
`sf.` ve `Sn.` bir cümleyi bitirir ve sonraki sözcüğü büyütür:

```spx-good
vb. fiyatlarımız düşük  →  Vb. Fiyatlarımız düşük
```

**Kendi satırında yalnız olmayan bir `#include` sıradan metindir.**

```spx-good
Önce. #include "intro"  →  Önce. #include "intro"
```

Aynısı, arkasında bir şey bulunan bir yönerge için ve boşluksuz `#include"intro"` için de
geçerlidir. Kural bu makinenin değil ailenin kuralıdır ve bir yönergeyi bütün satırı çözümlemeden
tanınır kılan da odur.

**Adı rakamla başlayan bir koşul, koşul değildir.** `?1x?evet` ile `hayır` arasında sıradan bir
seçime dönüşür:

```spx-good
{?1x?evet|hayır}  →  ?1x? Evet
```

**Sonraki bir parçanın başındaki `<…>` ayırıcı değildir** ve olduğu gibi yazılır:

```spx-good
[kırmızı|<ve>yeşil]  →  <ve>Yeşil kırmızı
```

**İlk** parçanın başındaki blok ise ayırıcıdır — karıştırmalar bölümünün açıldığı yazım budur:

```spx-good
[<ve>kırmızı|yeşil]  →  Yeşil ve kırmızı
```

Bir `|` işaretinden sonra her yerde sıradan metindir ve iki parça arasındaki bir ayırıcı,
birincinin **sonuna** yazılır.

**Bir parçanın sonundaki çıplak bir etiket, o çiftin ayırıcısı sayılır** ve kendi metni olarak
yazılır:

```spx-good
[bir<br>|iki]  →  Iki bir
```

Bu tohum altında ikisi öteki sırayla düştü, bu yüzden ayırıcı hiç çıkmadı. Üçüncü bir parçayla
düşeceği bir yer olur ve görünür:

```spx-good
[kırmızı|yeşil<br>|mavi]  →  Yeşil br mavi kırmızı
```

`<br>`, `yeşil` ile ondan sonra geleni arasında durur, karıştırma o çifti nereye koyarsa koysun.
Kapanan bir etiket (`</b>`), kendi kendini kapatan bir etiket (`<br/>`), öznitelikli bir etiket
(`<br class="x">`) ve bir parçanın ortasındaki bir etiket olduğu gibi kalır.

**Kapatılmamış bir açıklama sıradan metindir** — hiçbir şey açmaz ve `/#` yazılır:

```spx-good
önce /# bunun geri kalanı  →  Önce /# bunun geri kalanı
```

Ama yine de bir çiftin yarısıdır. Belgenin ilerisinde bir `#/` belirirse ikisi birbirini bulur ve
aralarındaki her şey gider — yazarın araya yazdıkları da dahil:

```
{a /# hop|b} orta #/ kuyruk  →  {a kuyruk
```

Yukarıdaki seçim ikinci seçeneğini ve kapanan ayracını yitirdi ve hiçbir tanı bunu söylemiyor:
metnin ANLAMI budur, makinenin görebileceği bir yanlış değil. Bir `/#` gerçekten kastediliyorsa
onun güvenli yeri şablonun gövdesi değil bir değişkenin değeridir.

## Sonra nereye bakmalı

Öteki belge, **Tanı sekmesi size ne söylüyor**, panelin gösterebileceği her satır için bir madde
taşır: ne anlama geldiği, neyin yol açtığı ve o dururken makinenin şablonla ne yaptığı. İmleç bir
yapının içindeyken F1'e basın; yardım o yapının bölümünde **o belgede** açılır: bir kaşlı ayraç
**Ayraçlar**'da, bir `[…]` **Karıştırmalar**'da, bir `#set` satırı **Tanımlar**'da.
