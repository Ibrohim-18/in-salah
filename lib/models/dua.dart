class DuaCategory {
  final String nameKey;
  final String icon;
  final List<Dua> duas;

  const DuaCategory({
    required this.nameKey,
    required this.icon,
    required this.duas,
  });
}

class Dua {
  final String titleKey;
  final String arabic;
  final String transliteration;
  final String translationKey;
  final String reference;

  const Dua({
    required this.titleKey,
    required this.arabic,
    required this.transliteration,
    required this.translationKey,
    required this.reference,
  });
}

const duaCategories = [
  DuaCategory(
    nameKey: 'duaCatMorningEvening',
    icon: 'sunrise',
    duas: [
      Dua(
        titleKey: 'duaMorningRemembrance',
        arabic: 'أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ',
        transliteration: "Asbahna wa asbahal-mulku lillah, walhamdu lillah, la ilaha illallahu wahdahu la sharika lah, lahul-mulku wa lahul-hamdu wa huwa 'ala kulli shay'in qadir",
        translationKey: 'duaMorningRemembranceTr',
        reference: 'Abu Dawud 4:317',
      ),
      Dua(
        titleKey: 'duaEveningRemembrance',
        arabic: 'أَمْسَيْنَا وَأَمْسَى الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ',
        transliteration: "Amsayna wa amsal-mulku lillah, walhamdu lillah, la ilaha illallahu wahdahu la sharika lah, lahul-mulku wa lahul-hamdu wa huwa 'ala kulli shay'in qadir",
        translationKey: 'duaEveningRemembranceTr',
        reference: 'Abu Dawud 4:318',
      ),
      Dua(
        titleKey: 'duaSayyidIstighfar',
        arabic: 'اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَهَ إِلَّا أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ، وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ، أَعُوذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ، أَبُوءُ لَكَ بِنِعْمَتِكَ عَلَيَّ، وَأَبُوءُ لَكَ بِذَنْبِي فَاغْفِرْ لِي فَإِنَّهُ لَا يَغْفِرُ الذُّنُوبَ إِلَّا أَنْتَ',
        transliteration: "Allahumma anta rabbi la ilaha illa ant, khalaqtani wa ana 'abduk, wa ana 'ala 'ahdika wa wa'dika mastata't, a'udhu bika min sharri ma sana't, abu'u laka bini'matika 'alayy, wa abu'u laka bidhanbi faghfir li fa innahu la yaghfirudh-dhunuba illa ant",
        translationKey: 'duaSayyidIstighfarTr',
        reference: 'Bukhari 7:150',
      ),
      Dua(
        titleKey: 'duaProtectionFromEvil',
        arabic: 'بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ وَهُوَ السَّمِيعُ الْعَلِيمُ',
        transliteration: "Bismillahil-ladhi la yadurru ma'asmihi shay'un fil-ardi wa la fis-sama'i wa huwas-sami'ul-'alim",
        translationKey: 'duaProtectionFromEvilTr',
        reference: 'Abu Dawud 4:323, Tirmidhi 5:465',
      ),
    ],
  ),
  DuaCategory(
    nameKey: 'duaCatBeforeAfterPrayer',
    icon: 'prayer',
    duas: [
      Dua(
        titleKey: 'duaOpeningIstiftah',
        arabic: 'سُبْحَانَكَ اللَّهُمَّ وَبِحَمْدِكَ، وَتَبَارَكَ اسْمُكَ، وَتَعَالَى جَدُّكَ، وَلَا إِلَهَ غَيْرُكَ',
        transliteration: "Subhanakallahumma wa bihamdik, wa tabarakasmuk, wa ta'ala jadduk, wa la ilaha ghayruk",
        translationKey: 'duaOpeningIstiftahTr',
        reference: 'Abu Dawud, Tirmidhi, An-Nasai',
      ),
      Dua(
        titleKey: 'duaBetweenProstrations',
        arabic: 'رَبِّ اغْفِرْ لِي، رَبِّ اغْفِرْ لِي',
        transliteration: 'Rabbighfir li, Rabbighfir li',
        translationKey: 'duaBetweenProstrationsTr',
        reference: 'Abu Dawud 1:231',
      ),
      Dua(
        titleKey: 'duaAfterTashahhud',
        arabic: 'اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنْ عَذَابِ جَهَنَّمَ، وَمِنْ عَذَابِ الْقَبْرِ، وَمِنْ فِتْنَةِ الْمَحْيَا وَالْمَمَاتِ، وَمِنْ شَرِّ فِتْنَةِ الْمَسِيحِ الدَّجَّالِ',
        transliteration: "Allahumma inni a'udhu bika min 'adhabi jahannam, wa min 'adhabil-qabr, wa min fitnatil-mahya wal-mamat, wa min sharri fitnatil-masihid-dajjal",
        translationKey: 'duaAfterTashahhudTr',
        reference: 'Bukhari 2:102, Muslim 1:412',
      ),
      Dua(
        titleKey: 'duaAfterPrayer',
        arabic: 'أَسْتَغْفِرُ اللَّهَ، أَسْتَغْفِرُ اللَّهَ، أَسْتَغْفِرُ اللَّهَ. اللَّهُمَّ أَنْتَ السَّلَامُ وَمِنْكَ السَّلَامُ، تَبَارَكْتَ يَا ذَا الْجَلَالِ وَالْإِكْرَامِ',
        transliteration: "Astaghfirullah, Astaghfirullah, Astaghfirullah. Allahumma antas-salam wa minkas-salam, tabarakta ya dhal-jalali wal-ikram",
        translationKey: 'duaAfterPrayerTr',
        reference: 'Muslim 1:414',
      ),
      Dua(
        titleKey: 'duaAyatKursi',
        arabic: 'اللَّهُ لَا إِلَهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ لَهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ مَنْ ذَا الَّذِي يَشْفَعُ عِنْدَهُ إِلَّا بِإِذْنِهِ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ وَلَا يُحِيطُونَ بِشَيْءٍ مِنْ عِلْمِهِ إِلَّا بِمَا شَاءَ وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالْأَرْضَ وَلَا يَئُودُهُ حِفْظُهُمَا وَهُوَ الْعَلِيُّ الْعَظِيمُ',
        transliteration: "Allahu la ilaha illa huwal-hayyul-qayyum, la ta'khudhuhu sinatun wa la nawm, lahu ma fis-samawati wa ma fil-ard, man dhal-ladhi yashfa'u 'indahu illa bi idhnih, ya'lamu ma bayna aydihim wa ma khalfahum, wa la yuhituna bishay'in min 'ilmihi illa bima sha', wasi'a kursiyyuhus-samawati wal-ard, wa la ya'uduhu hifdhuhuma, wa huwal-'aliyyul-'adhim",
        translationKey: 'duaAyatKursiTr',
        reference: 'Al-Baqarah 2:255',
      ),
    ],
  ),
  DuaCategory(
    nameKey: 'duaCatDailyLife',
    icon: 'daily',
    duas: [
      Dua(
        titleKey: 'duaBeforeEating',
        arabic: 'بِسْمِ اللَّهِ',
        transliteration: 'Bismillah',
        translationKey: 'duaBeforeEatingTr',
        reference: 'Abu Dawud, Tirmidhi',
      ),
      Dua(
        titleKey: 'duaAfterEating',
        arabic: 'الْحَمْدُ لِلَّهِ الَّذِي أَطْعَمَنِي هَذَا وَرَزَقَنِيهِ مِنْ غَيْرِ حَوْلٍ مِنِّي وَلَا قُوَّةٍ',
        transliteration: "Alhamdu lillahil-ladhi at'amani hadha wa razaqanihi min ghayri hawlin minni wa la quwwah",
        translationKey: 'duaAfterEatingTr',
        reference: 'Abu Dawud, Tirmidhi, Ibn Majah',
      ),
      Dua(
        titleKey: 'duaLeavingHome',
        arabic: 'بِسْمِ اللَّهِ، تَوَكَّلْتُ عَلَى اللَّهِ، وَلَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ',
        transliteration: "Bismillah, tawakkaltu 'alallah, wa la hawla wa la quwwata illa billah",
        translationKey: 'duaLeavingHomeTr',
        reference: 'Abu Dawud 4:325, Tirmidhi 5:490',
      ),
      Dua(
        titleKey: 'duaEnteringHome',
        arabic: 'بِسْمِ اللَّهِ وَلَجْنَا، وَبِسْمِ اللَّهِ خَرَجْنَا، وَعَلَى رَبِّنَا تَوَكَّلْنَا',
        transliteration: "Bismillahi walajna, wa bismillahi kharajna, wa 'ala rabbina tawakkalna",
        translationKey: 'duaEnteringHomeTr',
        reference: 'Abu Dawud 4:325',
      ),
      Dua(
        titleKey: 'duaBeforeSleeping',
        arabic: 'بِاسْمِكَ اللَّهُمَّ أَمُوتُ وَأَحْيَا',
        transliteration: 'Bismika Allahumma amutu wa ahya',
        translationKey: 'duaBeforeSleepingTr',
        reference: 'Bukhari 11:113',
      ),
      Dua(
        titleKey: 'duaWakingUp',
        arabic: 'الْحَمْدُ لِلَّهِ الَّذِي أَحْيَانَا بَعْدَمَا أَمَاتَنَا وَإِلَيْهِ النُّشُورُ',
        transliteration: "Alhamdu lillahil-ladhi ahyana ba'dama amatana wa ilayhin-nushur",
        translationKey: 'duaWakingUpTr',
        reference: 'Bukhari 11:113',
      ),
      Dua(
        titleKey: 'duaEnteringMasjid',
        arabic: 'اللَّهُمَّ افْتَحْ لِي أَبْوَابَ رَحْمَتِكَ',
        transliteration: "Allahummaftah li abwaba rahmatik",
        translationKey: 'duaEnteringMasjidTr',
        reference: 'Muslim 1:494',
      ),
      Dua(
        titleKey: 'duaLeavingMasjid',
        arabic: 'اللَّهُمَّ إِنِّي أَسْأَلُكَ مِنْ فَضْلِكَ',
        transliteration: "Allahumma inni as'aluka min fadlik",
        translationKey: 'duaLeavingMasjidTr',
        reference: 'Muslim 1:494',
      ),
    ],
  ),
  DuaCategory(
    nameKey: 'duaCatProtectionHealing',
    icon: 'shield',
    duas: [
      Dua(
        titleKey: 'duaForProtection',
        arabic: 'أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ مِنْ شَرِّ مَا خَلَقَ',
        transliteration: "A'udhu bikalimati-llahit-tammati min sharri ma khalaq",
        translationKey: 'duaForProtectionTr',
        reference: 'Muslim 4:2080',
      ),
      Dua(
        titleKey: 'duaVisitingSick',
        arabic: 'لَا بَأْسَ، طَهُورٌ إِنْ شَاءَ اللَّهُ',
        transliteration: "La ba's, tahurun in sha'Allah",
        translationKey: 'duaVisitingSickTr',
        reference: 'Bukhari 7:372',
      ),
      Dua(
        titleKey: 'duaForHealing',
        arabic: 'اللَّهُمَّ رَبَّ النَّاسِ أَذْهِبِ الْبَأْسَ، اشْفِهِ وَأَنْتَ الشَّافِي، لَا شِفَاءَ إِلَّا شِفَاؤُكَ، شِفَاءً لَا يُغَادِرُ سَقَمًا',
        transliteration: "Allahumma rabban-nas, adhhibil-ba's, ishfihi wa antash-shafi, la shifa'a illa shifa'uk, shifa'an la yughadiru saqama",
        translationKey: 'duaForHealingTr',
        reference: 'Bukhari 7:579, Muslim 4:1721',
      ),
      Dua(
        titleKey: 'duaAgainstAnxiety',
        arabic: 'اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْهَمِّ وَالْحَزَنِ، وَالْعَجْزِ وَالْكَسَلِ، وَالْبُخْلِ وَالْجُبْنِ، وَضَلَعِ الدَّيْنِ وَغَلَبَةِ الرِّجَالِ',
        transliteration: "Allahumma inni a'udhu bika minal-hammi wal-hazan, wal-'ajzi wal-kasal, wal-bukhli wal-jubn, wa dala'id-dayni wa ghalabatir-rijal",
        translationKey: 'duaAgainstAnxietyTr',
        reference: 'Bukhari 7:158',
      ),
    ],
  ),
  DuaCategory(
    nameKey: 'duaCatForgivenessRepentance',
    icon: 'repent',
    duas: [
      Dua(
        titleKey: 'duaSeekingForgiveness',
        arabic: 'أَسْتَغْفِرُ اللَّهَ الْعَظِيمَ الَّذِي لَا إِلَهَ إِلَّا هُوَ الْحَيَّ الْقَيُّومَ وَأَتُوبُ إِلَيْهِ',
        transliteration: "Astaghfirullaha al-'adhim alladhi la ilaha illa huwal-hayyul-qayyum wa atubu ilayh",
        translationKey: 'duaSeekingForgivenessTr',
        reference: 'Abu Dawud, Tirmidhi',
      ),
      Dua(
        titleKey: 'duaRepentanceYunus',
        arabic: 'لَا إِلَهَ إِلَّا أَنْتَ سُبْحَانَكَ إِنِّي كُنْتُ مِنَ الظَّالِمِينَ',
        transliteration: "La ilaha illa anta subhanaka inni kuntu minaz-zalimin",
        translationKey: 'duaRepentanceYunusTr',
        reference: 'Al-Anbiya 21:87',
      ),
      Dua(
        titleKey: 'duaDuaAdam',
        arabic: 'رَبَّنَا ظَلَمْنَا أَنْفُسَنَا وَإِنْ لَمْ تَغْفِرْ لَنَا وَتَرْحَمْنَا لَنَكُونَنَّ مِنَ الْخَاسِرِينَ',
        transliteration: "Rabbana zalamna anfusana wa in lam taghfir lana wa tarhamna lanakunnanna minal-khasirin",
        translationKey: 'duaDuaAdamTr',
        reference: 'Al-A\'raf 7:23',
      ),
    ],
  ),
  DuaCategory(
    nameKey: 'duaCatTravel',
    icon: 'travel',
    duas: [
      Dua(
        titleKey: 'duaStartingJourney',
        arabic: 'سُبْحَانَ الَّذِي سَخَّرَ لَنَا هَذَا وَمَا كُنَّا لَهُ مُقْرِنِينَ وَإِنَّا إِلَى رَبِّنَا لَمُنْقَلِبُونَ',
        transliteration: "Subhanal-ladhi sakhkhara lana hadha wa ma kunna lahu muqrinin, wa inna ila rabbina lamunqalibun",
        translationKey: 'duaStartingJourneyTr',
        reference: 'Az-Zukhruf 43:13-14',
      ),
      Dua(
        titleKey: 'duaReturningTravel',
        arabic: 'آيِبُونَ تَائِبُونَ عَابِدُونَ لِرَبِّنَا حَامِدُونَ',
        transliteration: "Ayibuna, ta'ibuna, 'abiduna, lirabbina hamidun",
        translationKey: 'duaReturningTravelTr',
        reference: 'Bukhari, Muslim',
      ),
    ],
  ),
  DuaCategory(
    nameKey: 'duaCatQuranic',
    icon: 'quran',
    duas: [
      Dua(
        titleKey: 'duaForGuidance',
        arabic: 'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ',
        transliteration: "Rabbana atina fid-dunya hasanatan wa fil-akhirati hasanatan wa qina 'adhaban-nar",
        translationKey: 'duaForGuidanceTr',
        reference: 'Al-Baqarah 2:201',
      ),
      Dua(
        titleKey: 'duaForPatience',
        arabic: 'رَبَّنَا أَفْرِغْ عَلَيْنَا صَبْرًا وَثَبِّتْ أَقْدَامَنَا وَانْصُرْنَا عَلَى الْقَوْمِ الْكَافِرِينَ',
        transliteration: "Rabbana afrigh 'alayna sabran wa thabbit aqdamana wansurna 'alal-qawmil-kafirin",
        translationKey: 'duaForPatienceTr',
        reference: 'Al-Baqarah 2:250',
      ),
      Dua(
        titleKey: 'duaForKnowledge',
        arabic: 'رَبِّ زِدْنِي عِلْمًا',
        transliteration: "Rabbi zidni 'ilma",
        translationKey: 'duaForKnowledgeTr',
        reference: 'Ta-Ha 20:114',
      ),
      Dua(
        titleKey: 'duaForParents',
        arabic: 'رَبِّ ارْحَمْهُمَا كَمَا رَبَّيَانِي صَغِيرًا',
        transliteration: "Rabbir-hamhuma kama rabbayanee saghira",
        translationKey: 'duaForParentsTr',
        reference: 'Al-Isra 17:24',
      ),
      Dua(
        titleKey: 'duaForOffspring',
        arabic: 'رَبِّ هَبْ لِي مِنْ لَدُنْكَ ذُرِّيَّةً طَيِّبَةً إِنَّكَ سَمِيعُ الدُّعَاءِ',
        transliteration: "Rabbi hab li min ladunka dhurriyyatan tayyibatan innaka sami'ud-du'a",
        translationKey: 'duaForOffspringTr',
        reference: 'Ali \'Imran 3:38',
      ),
      Dua(
        titleKey: 'duaIbrahim',
        arabic: 'رَبِّ اجْعَلْنِي مُقِيمَ الصَّلَاةِ وَمِنْ ذُرِّيَّتِي رَبَّنَا وَتَقَبَّلْ دُعَاءِ',
        transliteration: "Rabbij'alni muqimas-salati wa min dhurriyyati rabbana wa taqabbal du'a",
        translationKey: 'duaIbrahimTr',
        reference: 'Ibrahim 14:40',
      ),
    ],
  ),
];
