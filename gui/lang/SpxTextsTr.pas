(*
 * SpxTextsTr -- the window in Turkish.
 *
 * One language, one file. The order is TSpxStr's and nothing else: this is a positional
 * array, so a line moved here moves a caption on screen.
 *)
unit SpxTextsTr;

{$mode objfpc}{$H+}

interface

uses
  SpxStrIds;

const
  TEXTS_TR: array[TSpxStr] of string = (
      'Dosya', 'Yeni', 'Aç…', 'Kaydet', 'Farklı kaydet…', 'Seti yeniden yükle', 'Çıkış',
      'Düzen', 'Bul…', 'Sonrakini bul', 'Öncekini bul',
      'Görünüm', 'Araçlar solda', 'Araçlar sağda',
      'Arayüz dili', 'English', 'Русский', 'Şablondaki gibi',
      'G', 'İmlecin altındaki grup',
      'İmleç bir grubun içinde değil.', 'Uygula',
      'Reddedildi: sonuç bu listeden başka bir şey söylerdi — bir varyant | } { veya /# ' +
        'taşıyamaz.',
      'Bir varyantta satır sonu var, bu yüzden grup gösteriliyor ama düzenlenmiyor.',
      'Seçim', 'Koşul', 'Çoğul', 'Permütasyon',
      'D', 'V', 'Vr',
      '{…} içine al', '[…] içine al', 'Başka bir varyant göster', 'Sonucu kopyala',
      'Tümünü seç',

      'seed', 'Yeniden', 'Kopyala', 'Sayfa', 'Kaynak',
      'parça gösteriliyor', 'parça hiçbir şey üretmiyor',

      'Harf', 'bulunamadı', 'bulunan %d', '%d/%d', 'x',

      'Tanılama', 'Değişkenler', 'Varyantlar',
      'Düzey', 'Dosya', 'Yer', 'Mesaj',
      'hata', 'uyarı', 'Studio notu', 'belge',

      ' Tanımlar — belgenin içinde yaşarlar',
      ' Oturum değerleri — spintax olarak işlenir, belgeye hiç yazılmaz',
      'Tür', 'Ad', 'Değer', 'düz metin',

      'Kaç tane', 'seed', 'rastgele', 'Üret', 'Durdur',
      'Benzerleri at', 'Yalnızca birebir aynılar', 'Hepsini tut', 'shingle', 'sınır',
      '.xlsx olarak', '.txt olarak', 'Her biri bir dosya', '.txt içinde seed',
      'henüz üretilmedi', 'çalışıyor…', 'durduruluyor…',
      '%d varyant, %d atıldı, %d render, sonraki seed %d',
      '%d / %d — şablon bu sınırda daha fazlasını vermiyor (%d atıldı, %d render)',
      'durduruldu: %d varyant, %d atıldı, %d render',
      '%d / %d, %d atıldı, %d render',
      'belge değişti — bu set önceki metinden; ',
      '%1:s dosyasına %0:d satır yazıldı',
      '%d satır yazıldı; %d varyantta satır sonları boşluğa döndü — metni olduğu gibi ' +
        'istiyorsanız .xlsx ya da her biri bir dosya kullanın',
      '%1:s içine %0:d dosya yazıldı', '%d dosya yazıldı, sonra devam edilemedi',
      'dosya yazılamadı',
      '#', 'seed', 'uzunluk', 'metin',

      'Şablon aç', 'Şablonu kaydet', 'Spintax şablonları|*%s|Tüm dosyalar|*.*',
      'Excel çalışma kitabı|*.xlsx', 'Metin|*.txt',
      '.xlsx olarak dışa aktar', '.txt olarak dışa aktar', 'Dosyalar nereye', 'Varyantlar',
      'seed', 'varyant',
      'Spintax Studio', 'Belgede kaydedilmemiş değişiklikler var. Kaydedilsin mi?', 'Adsız',
      '%s — Spintax Studio',

      'hazır', 'geçerli', 'geçerli · uyarı: %d', 'hata: %d', ' · not: %d', '%s · %d ms',
      'Göster', 'Çıktı: %d KB — sayfa kendini yenilemez',

      'Kapat',

      'Büyüt', 'Küçült', 'Normal boyut', 'Açık', 'Koyu',

      'Eşit genişlik', 'Çift tıklama: eşit genişlik',

      'Düzenleyici yazı tipi', 'Otomatik',

      'Değer uygulanmadı: motor yönergeyi farklı okurdu',

      'Eklemeler — bu belgenin çektiği parçalar', 'Hedef', 'Bulundu', 'evet', 'YOK', 'küme yok',

      'Yardım', 'İçindekiler', 'Yardım dili', '%s dilinde henüz yardım yok.',

      'yardımdan', 'Belgeme ekle',

      'Hakkında',

      'Henüz makro yok — belgeye #set %name% = değer yazın, sonra metinde %name% kullanın.',
      'Henüz ekleme yok — #include "parça" başka bir dosyayı çeker, ve yalnızca satır başından.',

      'Solda bir şablon yazın, sağda ne ürettiğini görün. Doğrulama, değişkenler, dahil edilen dosyalar, varyant üretimi ve dışa aktarma: tümü çevrimdışı — hesap, ağ ve çalışma zamanı gerekmez.',
      'Lisanslar ve teşekkürler',

      'GSA içe aktarma',
      'GSA şablonu içe aktar…',
      'GSA şablonları|*.txt;*.spintax|Tüm dosyalar|*.*',
      'Şablondan %d değişken çıkarıldı.',
      'Bunlar oturum değerleridir: Değişkenler panelinde görünür ve belgeyle birlikte KAYDEDİLMEZ. Şablonun GSA''nın yazdığı gibi kalması için son işlem uygulanmadan işlenir.',
      '%d blok reddedildi ve olduğu gibi bırakıldı.',
      '…ve %d tane daha.',
      'İçe aktarma iptal edildi: şablon dönüştürülürken belge değişti.',

      'Olası varyantlar: %s',
      'Olası varyantlar: en az %s',

      (* the AI panel (ADR 0011) *)
      'Yapay zekâ taslağı',
      'Özet',
      'Modelin kullanabileceği değişkenler',
      'Modelin yanıtı',
      'Kanal',
      'Çeşitleme',
      'Dil',
      'İstemi kopyala',
      'Düzeltme istemini kopyala',
      'Belgeye ekle',
      'Durum',
      'Not',
      'İstem kopyalandı. Modelinize götürüp yanıtı geri getirin.',
      'Düzeltme istemi kopyalandı. Tam yerleri gösterir.',
      'Taslak eklendi. Karar tanılama panelinde.',
      'Önce bir özet yazın.',
      'Önce modelin yanıtını yapıştırın.',
      'Düzeltilecek hata yok.',
      'e-posta',
      'SMS',
      'push',
      'açılış sayfası',
      'genel',
      'temkinli',
      'dengeli',
      'cesur',
      '—',
      'yalın',
      'tamlayan',
      'yönelme',
      'belirtme',
      'araç',
      'bulunma',
      'Belgeyi değiştir',
      'Belge değiştirildi. Karar tanılama panelinde.',

      (* R1-4: the loop in the window (spec §4.5). The Turkish help never names the engine,
         so the verify line speaks of the check itself rather than inventing a term. *)
      'Düzelt',
      'Yapay zekâ ayarları…',
      'durduruldu',
      'modele soruluyor…',
      'taslak doğrulanıyor…',
      'düzeltme denemesi %d / %d',
      'Hata yok, ama deneme çıktılarının bir kısmı boş geliyor — çoğul biçimlerini kontrol edin. Taslak yapay zekâ panelinde, uygulanmadı.',
      'Taslak temiz, ama dahil edilen bir parçada hata var. O dosyayı düzeltin — yeniden üretmek onu onaramaz.',
      '%d hata kaldı — %d düzeltme denemesinden sonra. Taslak yapay zekâ panelinde, uygulanmadı.',
      'Yanıt yoldayken, doğrulandığı şeylerden biri değişti — belge, değerler ya da ayarlar. Taslak yanıt kutusunda, uygulanmadı.',
      'Bu profil kimlik doğruluyor ve bağlı bir anahtar yok. Anahtarı yapay zekâ panelinde girin.',
      'Uç nokta başka bir adrese gitmeyi istiyor (%s). İzlenmedi; bu isteniyorsa profili değiştirin.',
      'Bu makinenin dışına açık http, anahtarı ve metni şifresiz gönderirdi. https kullanın.',
      'Uç nokta anahtarı reddetti. Yapay zekâ panelinde kontrol edin.',
      'Uç nokta istek sınırı veya tükenmiş kota bildiriyor. Daha sonra deneyin.',
      'İstem bu modelin kabul ettiğinden daha uzun.',
      'İstek geçmedi: %s',
      'Uç nokta yanıt verdi, ama bu uygulamanın okuyamayacağı bir biçimde: %s',
      'Yanıtta şablon yoktu.',
      'Uç nokta bildiriyor: %s',
      'Bağlantı',
      'Biçim',
      'Uç nokta',
      'Model',
      'Yetkilendirme',
      'yok',
      'API anahtarı',
      'Anahtar',
      'Anahtarı bağla',
      'Anahtarı unut',
      'bu uç noktaya bağlı bir anahtar var',
      'bağlı anahtar yok',
      'uç nokta değişti — anahtarı yeni adrese bağlamak için yeniden girin',
      'Gönderim açık',
      'Bu uç noktaya gönderilsin mi?',
      '"Üret" ve "Düzelt" özeti, geçerli şablonu ve bildirilen değişkenleri bu profilin uç noktasına gönderir:'#10'%s'#10#10'API anahtarıyla yetkilendirmede anahtar, isteğin başlıklarında gider. Başka hiçbir anda hiçbir şey gönderilmez ve adres kendiliğinden asla değişmez: yönlendirme reddedilir ve gösterilir. O adresteki yazılımın metinle ne yaptığı, işletmecisine bağlıdır.'#10#10'Bunu istediğiniz zaman yapay zekâ ayarlarından kapatabilirsiniz.',

      (* R1-5: the report channel (Store policy 11.16) *)
      'Uygunsuz yapay zekâ çıktısını bildir…',

      (* the brief column's two modes (UX pass 2026-08-13) *)
      'Dönüştürülecek metin',
      'Önce dönüştürülecek metni yapıştırın.',

      (* find and replace (UX-plan item 8, 2026-08-14) *)
      'Değiştir…',
      'şununla değiştir',
      'Değiştir',
      'Tümünü değiştir',
      'Değiştirilen: %d',

      'Ekle',
      '/#…#/ içine al',
      '#set %ad% = değer',
      '#def %ad% = {a|b}',
      '#include "ad"',
      '{?ad?ise|değilse}',
      'Alınmadı: seçimin içindeki veya çevresindeki bir #/ açıklamayı erken bitirirdi.',
      'Alınmadı: tek başına bir |, kapanmamış bir ayraç veya açık bir açıklama koşulun anlamını değiştirirdi.',
      'Eklenmedi: imleç bir açıklama işaretini ikiye bölüyor.',
      'Uç nokta adresi okunamıyor — düzeltin, sonra anahtarı bağlayın.',
      'Taslak doğrulandı. Yanıt kutusunda bekliyor — eklemek ya da değiştirmek sizde.'
  );

implementation

end.
