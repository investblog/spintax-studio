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

Sağ yarımın üstündeki **Yeniden** bir sonrakini getirir. Hep aynısını istiyorsanız — iki
değişikliği karşılaştırırken diyelim — **seed** kutusunu işaretleyin, önizleme siz işareti
kaldırana veya sayıyı değiştirene kadar durur.

Sağ yarımın üstündeki anahtar **Sayfa** ve **Kaynak** sunar. Şablonlar çoğunlukla HTML'dir ve «bu nasıl
görünüyor» ile «hangi biçimleme çıktı» soruları birbirini yanıtlamaz: bozuk bir etiket gözün
atladığı hafif eğri bir yerleşim verir, etiket dolu bir düzyazı ise düzyazı gibi okunmaz. Yarımın
üstündeki anahtar neye baktığınızı değiştirir.

Şablonun bir bölümünü seçin, yalnız o bölüm işlenir — belgenin bütününün kapsamında, böylece
yukarıda tanımlanmış bir değişkeni kullanan bir parça, yerinde nasıl çıkacaksa öyle çıkar.

## Bul ve değiştir

**Ctrl+F** üst şeritte bir arama alanı açar. Yanındaki sayaç metnin kaç kez geçtiğini ve
hangi eşleşmede durduğunuzu söyler; **Enter** ileri, **Shift+Enter** geri adımlar, F3
doğrudan belgeden çalışır. Alandaki kutucuk işaretlenene dek büyük-küçük harf fark etmez —
katlama da motorun kendisinindir, bu yüzden Kiril ya da aksanlı bir harf, önizlemenin ikisini
tek harf saydığı yerde diğer biçimiyle eşleşir.

**Ctrl+H** — ya da **Değiştir…** menü öğesi — şeride ikinci bir satır ekler: değiştirilecek
metin ve iki düğme. **Değiştir** üzerinde durduğunuz eşleşmeyi değiştirip sonrakine geçer;
henüz bir şey bulunmamışken ilk basış yalnızca arar. **Tümünü değiştir** belgeyi tek seferde
tarar ve durum çubuğu kaç yerin değiştiğini söyler; tek bir Ctrl+Z tüm taramayı geri alır.

Değiştirme harfi harfinedir. Boş olabilir — bu siler — ve aranan metni içerebilir; tarama
döngüye girmez: değişecek yerler önceden, metnin eski hâli üzerinde belirlenir. Eşleşmeler
üst üste bindiğinde sayaç adımın uğrayabileceği her birini sayar, ama tarama yalnızca harf
paylaşmayanları değiştirir — bu yüzden "değiştirilen" dürüstçe daha küçük bir sayı
diyebilir.

Değiştirilmiş belge, yazılmış metinle aynı motor yolundan geçer: önizleme yeniden çizilir,
tanılar artık orada olan hakkında yanıt verir.

## İşaretleri ekleme

Dilin kendi işaretlerini belgeye koyan her şey **Ekle** menüsünde toplanır.

Üç sarma komutu seçimi olduğu gibi alır: **{…} içine al** onu bir seçime, **[…] içine al** bir karıştırmaya,
**/#…#/ içine al** (Ctrl+/) bir açıklamaya çevirir. Açıklamaya sarma, seçimin içindeki veya çevresindeki bir `#/` — ya da o noktada zaten açık bir
açıklama — bir açıklamayı erken bitirecekse geri çevirir: ilk kapatma işareti nerede durursa
dursun kazanır, metin dışarı düşerdi; bunu durum çubuğu söyler, çünkü makine susar. Seçim yokken Ctrl+/
çifti ekler ve imleci içinde bırakır.

Alttaki yapılar menüde okundukları gibi düşer. **#set %ad% = değer**, **#def %ad% = {a|b}** ve **#include "ad"** kendi satırlarını alır —
bir yönerge yalnızca satırını açtığında sayılır, imleçten önceki metin bu yüzden yukarıda
kalır, sonrası aşağı iner — ve ad seçili çıkar, üzerine yazılmaya hazır. Adları Latin
harfleriyle tutun: başka bir alfabedeki ad, sessizce, ad değildir. `#include` hedefi tek
istisnadır — parça adlarınızla yazıldığı gibi, harfi harfine karşılaştırılır.

**{?ad?ise|değilse}** satırın içinde yaşar. Seçim varken seçili metin "ise" yarısı olur — zaten yazılmış
olanı koşullu kılmanın yolu; seçim yokken bütün biçim girer. Yalın bir `|`, kapanmamış bir ayraç veya açık bir açıklama taşıyan seçim geri çevrilir: sarma,
çerçevelemek yerine söylediğini değiştirirdi.

Son öğe, yardımda açık olan örneği belgeye koyar — yardım panelinin kendi düğmesi, klavyeden
erişilir kılınmış hali.

## Alttaki paneller

Yandaki araç şeridi dört paneli, her seferinde birini açar.

**Tanılama** makinenin yanlış bulduklarını, her birini başladığı satır ve sütunla birlikte sıralar. Bir
satıra tıklamak imleci oraya koyar. Bu, makinenin başka her yerde verdiği hükmün ta kendisidir,
düzenleyicinin ikinci bir görüşü değil — bu yüzden bu panelin geçerli dediği bir şablonu öteki
makineler de kabul eder.

**Değişkenler** belgenizin tanımladığı adları ve yalnızca kullandığı adları gösterir. Kullandığı ve
hiçbir şeyin tanımlamadığı bir adı burada oturum için doldurabilirsiniz: yanına bir değer yazın,
önizleme onu alır. Değer kendi kendini anlatan bir metinse, kendi başına küçük bir şablon değilse,
**Düz metin** kutusunu işaretleyin.

**Varyantlar** bir seferde çok sayıda metin üretir. Kaç tane olduğunu söyleyin, üretin ve dışa
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

**Yapay zekâ taslağı**, bir şablonun ilk taslağını sizin yerinize yazar — elinizde olan bir
metinden ya da bir özetten. Kendi bölümünü hak ediyor: bir sonraki.

## Yapay zekâ taslağı

Bir şablon çoğunlukla zaten var olan bir metinden başlar — bir ürün açıklaması, bir mektup,
bir sayfa. **Yapay zekâ taslağı** paneli o metni ilk şablona çevirir: paneli araç çubuğundan açın, sol
sütunun başlığını **Dönüştürülecek metin** üzerinde bırakın, metni yapıştırın ve **Üret** düğmesine basın.
Gelen taslak belgeyi değiştirir, önizleme onu çizer ve tanı paneli yargısını verir — kendi
yazdıklarınızla aynı makine, aynı yargı. Bir Ctrl+Z eski belgenizi geri getirir; oradan sonra
kendi metniniz gibi düzenleyin, çünkü öyledir.

Yapıştıracak bir şey yoksa başlığı **Özet** konumuna alın ve ne istediğinizi anlatın.
Üstteki alanlar taslağı iki kipte de yönlendirir: **Kanal** — bir mektup, bir SMS ve bir
anlık bildirim farklı üsluplarda yazılır; **Çeşitleme** — çeşitlemeler birbirinden ne kadar
uzaklaşabilir; yanıtın dili; ve adlarıyla bildirilen **Modelin kullanabileceği değişkenler**. Durum sütunu, doldurmaya değer olan bölümdür. Değişken olduğu gibi yerleştirilir, onu hiçbir şey çekimlemez: durumları olan bir dilde cümle, değerin hâlihazırda taşıdığı biçimin çevresine kurulmalıdır ve model ancak her adın hangi biçimi taşıdığı söylendiğinde doğru seçer. Addan çıkarılamaz: gerçek bir şablon kümesinde araç durumundaki biçimler, adı belirtme durumu diyen bir değişkende duruyordu.

Yanıta inanılmaz, yanıt doğrulanır: taslak, belgenize yaklaşmadan önce bu pencerenin kendi
makinesinden geçer ve yargı hata bulursa döngü, bir şey teslim etmeden önce modelden onları
onarmasını ister — durum çubuğu turları sayar. Belgeyi yalnızca temiz bir taslak değiştirir;
gerisi **Modelin yanıtı** alanına düşer, durum satırı nedenini söyler ve sizin hiçbir şeyinizin
üzerine yazılmaz. Kendi düzenlemeleriniz de aynı biçimde korunur: yanıt yoldayken yazdıysanız
taslak panelde bekler. Çalışırken **Üret** düğmesinde **Durdur** yazar — turu bırakmak için
basın.

**Düzelt**, aynı döngünün mevcut belgenize çevrilmiş hâlidir: tanı hata bulduğunda uyanır,
belgeyi tam itirazlarla birlikte gönderir ve düzeltilmiş sürümü aynı özenle uygular.

### Bağlantı, ve kimin anahtarı

Kurulduğu hâliyle uygulama hiçbir yere hiçbir şey göndermez. **Üret** ve **Düzelt** ağa ancak
panelin altındaki bağlantıyı kurup izin verdikten sonra çıkar. Uç noktanızın konuştuğu
**Biçim**'i seçin — **Anthropic Messages** ya da **OpenAI-compatible** —, **Uç nokta** adresini ve
**Model** alanındaki adı — Anthropic için okun altındaki liste güncel adlar önerir; diğer
durumlarda uç noktanızın beklediği adı yazın. **Yetkilendirme**, anahtarın yola çıkıp çıkmayacağını söyler: barındırılan sağlayıcılar için
**API anahtarı**, anahtar istemeyen sunucular için **yok**.

Anahtar sizindir, kendi hesabınızda yapılmıştır — uygulamanın hiçbir zaman kendi anahtarı
yoktur:

- **Anthropic** — anahtarı `console.anthropic.com` üzerinde, API keys bölümünde oluşturun.
- **OpenAI** — `platform.openai.com`, API keys bölümü; göndermek için hesapta faturalandırma
  da açık olmalı.
- **OpenAI-compatible** bir ailedir, tek bir şirket değil: OpenRouter aynı biçimde, tek
  anahtar altında birçok modelle yanıt verir; kendi bilgisayarınızdaki sunucular — Ollama,
  LM Studio — çoğunlukla hiç anahtar istemez: **Yetkilendirme** alanını **yok** yapın.

**Anahtarı bağla**, anahtarı Windows Kimlik Bilgisi Yöneticisine koyar, Windows hesabınız için
şifrelenmiş olarak — bir dosyaya değil ve asla belgeye değil. Alan sonra anahtarın ilk
karakterlerini gösterir, hangisinin bağlı olduğu görünsün diye; **Anahtarı unut** onu kaldırır.
Anahtar, girildiği yere bağlıdır — şema, sunucu adı ve bağlantı noktası: bunlardan biri
değişirse panel anahtarı yeniden ister.

İlk basış açık sözlerle sorar — **Bu uç noktaya gönderilsin mi?** — alıcıyı adıyla anarak. Yola çıkan: özetinizden ya da metninizden kurulan istem — seçtiğiniz kanal, çeşitleme ve
dille birlikte —, bildirilen değişkenler, onarımda mevcut şablon ve tanısı, profilinizden model adı ve yanıt
uzunluğu için bir tavan, **API anahtarı** yetkilendirmesinde de istek başlıklarındaki anahtar; başka hiçbir şey ve başka hiçbir anda. Alıcı sizsiz değişmez: bir yönlendirme izlenmek yerine reddedilir; şifrelenmemiş bir `http` adresi yalnızca bu
makinede kabul edilir.
İzin, anahtarın bağlandığı yere bağlıdır — şema, sunucu adı ve bağlantı noktası — ve
ayarlardaki **Gönderim açık** işaretinde görünür — istediğiniz an kaldırın: yeni bir şey
gönderilmez ve zaten yolda olan bir yanıt asla uygulanmaz. Seçtiğiniz adresteki yazılımın metinle ne yaptığını
söylemek işletmecisine düşer: istek, profilinizdeki adrese gider ve başka hiçbir yere değil.

### Aynı döngü, ağ olmadan

İstemlerin ne anahtara ne bağlantıya ihtiyacı var — modeliniz bir sohbet penceresinde
yaşıyorsa yol budur ve döngüyü burada siz çevirirsiniz: makine yargısını yapıştırmadan sonra
verir, önce değil. **İstemi kopyala** tam istemi panoya koyar; onu kullandığınız modele götürün,
yanıtı **Modelin yanıtı** alanına yapıştırın ve **Belgeye ekle** düğmesine basın. Tanı hata bulursa
**Düzeltme istemini kopyala** ikinci istemi kurar: tüm belgeyi satırları numaralanmış taşır ve makinenin itiraz
ettiği yerleri tek tek adlandırır. Onun yanıtı, düzeltilmiş belgenin tamamıdır — geri getirin
ve **Belgeyi değiştir** düğmesine basın; **Belgeye ekle** bozuk olanı yerinde bırakır, düzeltilmiş kopyayı
yanına koyardı.

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
