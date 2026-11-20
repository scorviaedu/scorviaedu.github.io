# Scorvia

**Yüksək bala gedən yol** — bütün fənlər üzrə onlayn sınaq və dərs materialları platforması.

🌐 **Sayt:** https://scorvia.github.io/
👤 **Admin:** `aliqurbanovfh`

## Fənlər

Azərbaycan dili, Ədəbiyyat, Riyaziyyat, Fizika, Kimya, Biologiya, İngilis dili, Rus dili, İnformatika,
Azərbaycan tarixi, Ümumi tarix, Coğrafiya, Məntiq və Digər.
Siyahı `assets/js/config.js` faylında, `SUBJECTS` bölməsindədir. Yeni fənn əlavə etmək üçün sona bir sətir yazmaq kifayətdir.

Sınaq, material, ev tapşırığı və sual bankındakı hər sual bir fənnə bağlanır. Admin paneldə fənn üzrə süzgəc var.
Şagird portalında sınaqlar və materiallar fənlər üzrə tablarla açılır.

## Nə var

- **Qeydiyyat və təsdiq:** şagird qeydiyyatdan keçir, admin təsdiqləyəndən sonra portal açılır.
- **Sınaqlar:**
  - PDF + onlayn cavab kartı və ya tam onlayn sınaq
  - taymer, avtomatik yadda saxlama və serverdə yoxlama
  - variantlar (A, B, C...), qarışdırma, bölmələr üzrə nəticə
  - esse, kağız sınaq, Excel və PDF hesabatlar
- **Cavab açarı formatı:** `1 A, 2 C, 4 BBAA, 10 cavab/variant, 26 esse`
- **Materiallar:** PDF-lərin hər səhifəsində şagirdin adı və şəxsi kodu (`SC-XXXXXX`) su nişanı kimi yazılır.
- **Digər bölmələr:**
  - ev tapşırıqları və sual bankı
  - canlı viktorina, gündəlik məşq
  - davamiyyət, chat, valideyn girişi, aylıq hesabat, sertifikat
- **Qoruma:**
  - pozuntu aşkarlama (F12, səhifədən çıxma və s.): 2 xəbərdarlıqdan sonra blok
  - Tor bloku, tək cihaz
  - Telegram bildirişləri
- Hamısı pulsuzdur: **GitHub Pages** + **Supabase** (Frankfurt).

## Qurulub

- Supabase layihəsi (indiki adı "Fennora", Supabase-də dəyişmək olar): bütün baza, fayl qovluqları və avtomatik işlər hazırdır.
- `assets/js/config.js` faylına layihənin açarları yazılıb.

## Bir dəfə edilməli olanlar

1. **Supabase → Authentication → Sign In / Providers → Email** bölməsini aç:
   - **Confirm email** ayarını söndür
   - **Minimum password length** sahəsinə 8 yaz
   - **Save** bas
2. Saytda `aliqurbanovfh` istifadəçi adı ilə qeydiyyatdan keç. Admin hüququnu Claude verir, və ya SQL Editor-da bunu işlət:
   ```sql
   update public.profiles set role = 'admin', status = 'approved', approved_at = now()
   where username = 'aliqurbanovfh';
   ```
3. **Telegram bildirişləri (istəyə görə):**
   - @BotFather ilə bot yarat
   - @userinfobot-dan öz ID-ni götür
   - SQL Editor-da bunu işlət: `select public.set_telegram('TOKEN', 'ID');`

## Gündəlik istifadə

- **Yeni sınaq:**
  1. **Admin panel → Sınaqlar → + Yeni sınaq** aç.
  2. **Fənni** seç, ad yaz, PDF yüklə və vaxtı qoy.
  3. Cavab açarını yapışdır və **Cavab kartını yarat** bas.
  4. **Şagirdlər görsün** işarələ və **Yadda saxla** bas.
- **Material:** **Materiallar** bölməsində fənni seç, PDF yüklə.
- **Fənn üzrə baxış:** Sınaqlar, Materiallar və Sual bankı bölmələrinin yuxarısındakı **"Bütün fənlər"** seçimindən istifadə et.
