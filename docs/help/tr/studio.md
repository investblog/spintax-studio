# Spintax Studio

Bu program şablonlar için bir düzenleyicidir. Şablon, içinde birkaç işaretli yer bulunan sıradan
metindir ve tek bir şablon pek çok farklı metin üretebilir — metinleri tek tek yazmak yerine bir
şablon yazmanın bütün anlamı budur.

Pencere iki yarımdan oluşur. Solda sizin şablonunuz, düzenlediğiniz şey. Sağda ondan çıkan
metinlerden biri, siz yazarken yeniden çizilir. Aralarında basılacak bir şey yoktur: sağda
gördüğünüz, o anda solda duran için makinenin geri verdiğidir.

```spx-fixture
locale: tr
seed: 7
empty: (boş)
```

Makine bu programın içindedir ve bir ailenin Pascal üyesidir: aynı dil JavaScript, PHP ve Python
için de yayımlanır. Dördü de tek bir ortak sınama kümesine tutulan bağımsız programlardır, bu
yüzden bir şablonun NE ANLAMA GELDİĞİ hepsinde aynıdır: yapılar, geçerlilik hükmü, son rötuşlar.
Bu pencerenin geçerli dediği bir şablon orada da geçerlidir.

Söz verilmeyen ve karşılaştırırken önem kazanan şey: kura. Bir tohum önizlemeyi BURADA
yinelenebilir kılar — aynı tohum ve aynı şablon yarın da aynı metni verir — ama aynı tohum
JavaScript makinesinde başka bir seçenek çekebilir. Tohumlar kendi işinizi yeniden üretmek içindir,
başka bir makineyi tutturmak için değil.

Buradaki her şey ağ bağlantısı olmadan çalışır. Hesap yok, oturum açma yok ve açılacak bir şey yok:
programı açın, çalışıyor.

## İki yarım

Sola yazılır. Sağ yarım kısa bir duraklamadan sonra yeniden çizilir, böylece önizleme her harfi
değil bir cümleyi izler.

İçinde seçim bulunan bir şablonun tek bir yanıtı yoktur ve önizleme bunlardan birini gösterir:

```spx-good
{Merhaba|Selam} herkese.  →  Merhaba herkese.
```

Sağ yarımın üstündeki **Yeniden çek** bir sonrakini getirir. Hep aynısını istiyorsanız — iki
değişikliği karşılaştırırken diyelim — **seed** kutusunu işaretleyin, önizleme siz işareti
kaldırana veya sayıyı değiştirene kadar durur.

Sağ yarımın üstündeki anahtar **Sayfa** ve **Kaynak** sunar. Şablonlar çoğunlukla HTML'dir ve «bu nasıl
görünüyor» ile «hangi biçimleme çıktı» soruları birbirini yanıtlamaz: bozuk bir etiket gözün
atladığı hafif eğri bir yerleşim verir, etiket dolu bir düzyazı ise düzyazı gibi okunmaz. Yarımın
üstündeki anahtar neye baktığınızı değiştirir.

Şablonun bir bölümünü seçin, yalnız o bölüm işlenir — belgenin bütününün kapsamında, böylece
yukarıda tanımlanmış bir değişkeni kullanan bir parça, yerinde nasıl çıkacaksa öyle çıkar.

## Alttaki paneller

Yandaki araç şeridi üç paneli, her seferinde birini açar.

**Tanı** makinenin yanlış bulduklarını, her birini başladığı satır ve sütunla birlikte sıralar. Bir
satıra tıklamak imleci oraya koyar. Bu, makinenin başka her yerde verdiği hükmün ta kendisidir,
düzenleyicinin ikinci bir görüşü değil — bu yüzden bu panelin geçerli dediği bir şablonu öteki
makineler de kabul eder.

**Değişkenler** belgenizin tanımladığı adları ve yalnızca kullandığı adları gösterir. Kullandığı ve
hiçbir şeyin tanımlamadığı bir adı burada oturum için doldurabilirsiniz: yanına bir değer yazın,
önizleme onu alır. Değer kendi kendini anlatan bir metinse, kendi başına küçük bir şablon değilse,
**Düz metin** kutusunu işaretleyin.

**Çeşitlemeler** bir seferde çok sayıda metin üretir. Kaç tane olduğunu söyleyin, üretin ve dışa
aktarmadan önce listede okuyun. Neredeyse aynı olanlar üretilirken elenebilir ve bir tohum bütün
partiyi yinelenebilir kılar: aynı tohum ve aynı şablon yarın da aynı çeşitlemeleri verir.

Bu alanların yanında panel, şablonun toplamda kaç çeşitleme verebileceğini söyler: `{a|b} ve {c|d}`
dört tane eder. Bu sayı, elli tane üretip okuyarak fark etmeden önce şablonun zayıf olduğunu size
söyler.

Yalnızca her seçim rastlantıya bırakıldığı sürece kesin bir sayıdır. Bir koşul, bir sayı biçimi ya
da kümenin hedefini bulundurmadığı bir `#include` başka bir şeyce belirlenir — sizin vereceğiniz
bir değerce, bir sayıca, belki gelecek bir parçaca — ve o zaman panel **en az** der. Dürüst söz
budur: bir değer vermek metin ancak ekler, hiç eksiltmez. Okunamayacak kadar büyük bir sayı bir
trilyonda durur ve aynı nedenle **en az** der.

Bir çeşitleme, doldurulmuş bir şablondur — her yapıda yapılmış bir seçim — ve bu, başka türlü
okunan bir metinle aynı şey değildir. `{a|a}` iki çeşitleme ve tek bir metindir, hem de bilerek:
iki olasılık tek bir düzenlemeden sonra ayrışabilir ve onları birleştirmek önce bütün bileşimleri
üretmek demek olurdu — yani bu sayının size tam da kazandırdığı iş. Bir `#def` de aynı şekilde
sayılır: makine onu her işlemede bir kez çeker, gittiğiniz dal onu kullansa da kullanmasa da.

Dışa aktarma bunları üç yolla yazar: XLSX çalışma kitabı olarak, satır başına bir çeşitleme düşen
düz metin olarak ya da seçtiğiniz bir klasörde çeşitleme başına bir dosya olarak.

## Grup düzenleyici

İmleci bir `{a|b|c}` içine koyun ve araç şeridinden grup düzenleyiciyi açın. Seçenekleri satırlar
olarak sıralar: değiştirin, bir tane ekleyin, bir tane çıkarın; belge buna göre yeniden yazılır.

Grubun ne SÖYLEDİĞİNİ değil ne ANLAMA GELDİĞİNİ değiştirecek düzenlemeleri geri çevirir: bir
seçeneğin içine yazılan bir `|` bir olasılığı ikiye böler, bir `}` ise grubu erkenden kapatır. Geri
çevirdiğinde bunu söyler ve belgeye dokunmaz.

## Ayarlar

Görünüm menüsündedirler ve her biri oturumlar arasında hatırlanır: arayüzün dili ve şablonu izleyip
izlemediği, araç şeridinin hangi yanda olduğu, tema, düzenleyicinin yazı tipi ve boyutu,
önizlemenin sayfayı mı kaynağı mı gösterdiği, GSA içe aktarma anahtarı, hangi panelin açık olduğu
ve açılıp kapanan panellerin genişlikleri.

Arayüz on dört dil konuşur, aynı menüden seçilir. Bu, sayı biçimlerini belirleyen ve sağ yarımın
üstünden ayarlanan şablon dilinden ayrıdır.

## GSA şablonu içe aktarma

Bu parça siz açana dek kapalıdır, **Görünüm**, **GSA içe aktarma** altında; çünkü şablon yazanların
çoğu GSA Search Engine Ranker'ı hiç kullanmamıştır. Açıkken **Dosya**, **GSA şablonu içe aktar…**
bir SER şablonunu okur ve bu dile çevirir.

Çeviri belirli bir biçimde temkinlidir. Sadakatle ifade edemediğini sessizce işlenen bir şeye
dönüştürmek yerine geri çevirir ve size söyler. Metinde kalsa yanlış okunacak yapılar — BBCode
köşeli ayraçları, bir bağlantı içindeki `#`, bir `#file[...]` makrosu — değişkenlere taşınır ve
özet kaç tane olduğunu söyler.

Sonuç hakkında bilinmesi gereken iki şey:

- **Taşınan değerler oturum değerleridir.** Değişkenler panelinde görünürler ve belgeyle birlikte
  kaydedilmezler. Çevrilmiş şablonu kaydedin, yarın açın; taşınan metnin durduğu yerde `%…%`
  görürsünüz. İçe aktardığınız dosyadan hiçbir şey yitmez — o el değmemiş kalır — ama çevrilmiş
  belge kendi başına yeterli değildir.
- **Son rötuş geçişi olmadan işlenir.** Buradaki başka her belge dil kılavuzunda anlatılan son
  rötuşları alır; çevrilmiş bir şablon almaz, çünkü düzeltmek bizim metnimiz değildir. Başkasınındır,
  çoğunlukla GSA'ya geri dönüş yolundadır ve karakteri karakterine sağ çıkmalıdır.

İçe aktarılan belge adsız ve kaydedilmemiştir, yeni bir belge gibi. Seçtiğiniz dosya tam olarak
olduğu gibi kalır.
