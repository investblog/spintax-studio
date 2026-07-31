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

      'hazır', 'geçerli', 'geçerli, %d uyarı', '%d hata', ' · %d not', '%s · %d ms',
      'Göster', 'Çıktı: %d KB — sayfa kendini yenilemez',

      'Kapat',

      'Büyüt', 'Küçült', 'Normal boyut', 'Açık', 'Koyu',

      'Eşit genişlik', 'Çift tıklama: eşit genişlik',

      'Düzenleyici yazı tipi', 'Otomatik',

      'Değer uygulanmadı: motor yönergeyi farklı okurdu',

      'Eklemeler — bu belgenin çektiği parçalar', 'Hedef', 'Bulundu', 'evet', 'YOK', 'küme yok',

      'Yardım', 'İçindekiler', 'Yardım dili', '%s dilinde henüz yardım yok.',

      'yardımdan', 'Belgeme ekle'
  );

implementation

end.
