// =========================================================
//  SCORVIA — tənzimləmələr
//  (Bu açar "publishable/anon" açardır — açıq olması təhlükəsizdir,
//   bütün qoruma bazadakı qaydalarla təmin olunur.)
// =========================================================

export const SUPABASE_URL = "https://frmtdadawvrkauvxzewq.supabase.co";
export const SUPABASE_KEY = "sb_publishable_YDW1nK5KihmG7bEPLOafSw_tj54kJDi";

// Şagirdlər istifadəçi adı ilə girir. Arxa planda istifadəçi adı
// bu domenlə e-poçt formatına çevrilir (heç bir e-poçt göndərilmir).
// Sayt işə düşəndən sonra DƏYİŞMƏ — köhnə hesablarla giriş işləməz.
export const EMAIL_DOMAIN = "scorvia.github.io";

// Qeydiyyatda seçilə bilən siniflər
export const CLASSES = ["5", "6", "7", "8", "9", "10", "11", "Magistratura"];
// Magistrantlar ayrıca bölmədir: materiallar, elanlar, ev tapşırıqları və reytinq məktəblilərdən ayrıdır
export const MAG_CLASS = "Magistratura";

// Fənlər. "id" bazada saxlanır — sonradan dəyişmə (adı, ikonu, rəngi dəyişmək olar).
// Yeni fənn əlavə etmək üçün sona yeni sətir yaz.
export const SUBJECTS = [
  { id: "az",   name: "Azərbaycan dili",   icon: "📖", color: "#0e8c7f" },
  { id: "lit",  name: "Ədəbiyyat",         icon: "🖋️", color: "#8a5a2b" },
  { id: "math", name: "Riyaziyyat",        icon: "➗", color: "#2f6fe0" },
  { id: "phys", name: "Fizika",            icon: "⚛️", color: "#6a4fe0" },
  { id: "chem", name: "Kimya",             icon: "🧪", color: "#d1495b" },
  { id: "bio",  name: "Biologiya",         icon: "🧬", color: "#2e9e4f" },
  { id: "en",   name: "İngilis dili",      icon: "🇬🇧", color: "#c0392b" },
  { id: "ru",   name: "Rus dili",          icon: "🇷🇺", color: "#3d5a99" },
  { id: "it",   name: "İnformatika",       icon: "💻", color: "#0f7fa8" },
  { id: "hist", name: "Azərbaycan tarixi", icon: "🏛️", color: "#a0522d" },
  { id: "wh",   name: "Ümumi tarix",       icon: "🌍", color: "#7a6a3a" },
  { id: "geo",  name: "Coğrafiya",         icon: "🗺️", color: "#1f9e8f" },
  { id: "logic", name: "Məntiq",           icon: "🧩", color: "#e07a2f" },
  { id: "other", name: "Digər",            icon: "📚", color: "#5b6475" },
];
export const subjectOf = (id) => SUBJECTS.find((s) => s.id === id) || null;
// Kiçik fənn nişanı (HTML). Fənn seçilməyibsə boş qaytarır.
export function subjectChip(id) {
  const s = subjectOf(id);
  if (!s) return "";
  return `<span class="subj-chip" style="--subj:${s.color}">${s.icon} ${s.name}</span>`;
}
// <select> üçün seçimlər
export function subjectOptions(selected, emptyLabel = "— Fənn seç —") {
  return `<option value="">${emptyLabel}</option>` + SUBJECTS.map((s) =>
    `<option value="${s.id}"${s.id === selected ? " selected" : ""}>${s.icon} ${s.name}</option>`).join("");
}

// Sertifikat və hesabatlarda imza
export const TEACHER_NAME = "Scorvia";
export const TEACHER_TITLE = "Onlayn təhsil platforması";

// Bu faizdən yuxarı nəticə üçün şagird sertifikat yükləyə bilər
export const CERT_MIN_PERCENT = 85;

// Esse yoxlanarkən meyarlar (esse balı bunlara bərabər bölünür)
export const RUBRIC = ["Məzmun", "Dil və qrammatika", "Lüğət", "Quruluş"];
