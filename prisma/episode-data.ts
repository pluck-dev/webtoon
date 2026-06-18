export type CharacterSeed = {
  key: string;
  name: string;
  description: string;
  voiceGuide: string;
  color: string;
  visual: string;
};

export type CutSeed = {
  imageUrl: string;
  visual: string;
  caption: string;
  characterKey: string;
  text: string;
  direction: string;
};

export type EpisodeSeed = {
  slug: string;
  title: string;
  logline: string;
  maxSeconds: number;
  thumbnailUrl: string;
  characters: CharacterSeed[];
  cuts: CutSeed[];
};

function image(slug: string, index: number) {
  return `/generated/${slug}-${String(index).padStart(2, '0')}.png`;
}

export const episodes: EpisodeSeed[] = [
  {
    slug: 'ex-interviewer',
    title: '전남친이 면접관이었다',
    logline: '면접장에서 3년 전 사라진 전남친을 면접관으로 마주친다.',
    maxSeconds: 58,
    thumbnailUrl: image('ex-interviewer', 1),
    characters: [
      {
        key: 'seoyoon',
        name: '서윤',
        description: '27세. 코랄 니트 재킷을 입은 지원자. 상처를 숨기지만 말끝이 날카롭다.',
        voiceGuide: '웃는 척하지만 감정이 눌려 있다. 마지막 단어에서 힘을 빼지 않는다.',
        color: '#ef6f5e',
        visual: 'Korean woman, 27, short black bob hair, coral knit jacket, small gold earrings, tense but elegant expression'
      },
      {
        key: 'doha',
        name: '도하',
        description: '29세. 네이비 셔츠의 차분한 면접관. 미안함을 숨기고 있다.',
        voiceGuide: '낮고 차분하게 말한다. 질문처럼 들리지만 속으로는 흔들린다.',
        color: '#31435f',
        visual: 'Korean man, 29, dark wavy hair, navy shirt, clean office style, controlled expression with hidden guilt'
      }
    ],
    cuts: [
      { imageUrl: image('ex-interviewer', 1), visual: 'wide office interview room, Seoyoon opens the glass door and freezes as Doha sits at the table', caption: '면접실 문이 열리는 순간, 서윤은 숨을 멈췄다.', characterKey: 'seoyoon', text: '면접관이... 당신이라고요?', direction: '숨을 한 번 삼키고 작게 시작' },
      { imageUrl: image('ex-interviewer', 2), visual: 'Doha lowers the resume on the table, close shot from Seoyoon shoulder, city window behind him', caption: '도하는 이력서를 내려놓고 사적인 질문처럼 말했다.', characterKey: 'doha', text: '오랜만이네요. 지원자로 올 줄은 몰랐습니다.', direction: '담담하지만 끝을 흐리게' },
      { imageUrl: image('ex-interviewer', 3), visual: 'Seoyoon sits across from him, forced smile, hands clenched on her portfolio', caption: '서윤은 웃었다. 손끝은 이미 하얗게 질려 있었다.', characterKey: 'seoyoon', text: '저도요. 도망친 사람이 면접관일 줄은 몰랐네요.', direction: '웃으며 찌르듯이' },
      { imageUrl: image('ex-interviewer', 4), visual: 'Doha looks down at a red-marked resume page, interview table tension', caption: '첫 질문은 이력서가 아니라 과거에서 시작됐다.', characterKey: 'doha', text: '그때 왜 아무 말도 안 했습니까?', direction: '낮게, 감정을 누르면서' },
      { imageUrl: image('ex-interviewer', 5), visual: 'Seoyoon close-up, city light on her eyes, she inhales before answering', caption: '서윤은 대답 대신 오래 참았던 숨을 내쉬었다.', characterKey: 'seoyoon', text: '말할 기회는 있었어요. 당신이 안 들었을 뿐이죠.', direction: '차분하게, 단어마다 힘을 줘서' },
      { imageUrl: image('ex-interviewer', 6), visual: 'flashback-like reflection in office window, younger Doha walking away in rain', caption: '유리창에 비친 기억이 두 사람 사이를 갈랐다.', characterKey: 'doha', text: '난 네가 날 버린 줄 알았습니다.', direction: '처음으로 흔들리는 목소리' },
      { imageUrl: image('ex-interviewer', 7), visual: 'Seoyoon slides an old envelope across the interview table', caption: '서윤은 낡은 봉투를 면접 자료 위에 올렸다.', characterKey: 'seoyoon', text: '이 편지, 세 번이나 반송됐어요.', direction: '꾹 눌러 말하다 마지막에 작게' },
      { imageUrl: image('ex-interviewer', 8), visual: 'Doha opens envelope with trembling fingers, close-up of paper without readable text', caption: '도하의 손끝이 처음으로 흔들렸다.', characterKey: 'doha', text: '이걸... 왜 이제야 보여줍니까?', direction: '숨이 막힌 듯이' },
      { imageUrl: image('ex-interviewer', 9), visual: 'Interview assistant knocks outside blurred glass door, both ignore it', caption: '밖에서는 다음 지원자를 부르는 소리가 들렸다.', characterKey: 'seoyoon', text: '오늘은 면접 보러 온 거지, 용서하러 온 게 아니에요.', direction: '단호하게 선을 긋기' },
      { imageUrl: image('ex-interviewer', 10), visual: 'Doha stands abruptly, chair pushed back, city skyline behind him', caption: '도하는 면접관의 자세를 처음으로 잃었다.', characterKey: 'doha', text: '그럼 왜 여기까지 왔습니까?', direction: '감정을 억누르다 터지듯' },
      { imageUrl: image('ex-interviewer', 11), visual: 'Seoyoon looks at company logo wall, composed but hurt', caption: '서윤은 회사 로고가 아닌 그의 눈을 봤다.', characterKey: 'seoyoon', text: '내 실력으로 들어와서, 당신 앞에서 안 무너지려고요.', direction: '낮고 또렷하게' },
      { imageUrl: image('ex-interviewer', 12), visual: 'Doha picks up evaluation pen but cannot write, close dramatic shot', caption: '평가표 위에 펜촉이 멈췄다.', characterKey: 'doha', text: '개인 감정은 평가에 넣지 않겠습니다.', direction: '프로처럼 말하려 애씀' },
      { imageUrl: image('ex-interviewer', 13), visual: 'Seoyoon leans forward slightly, fierce eyes, interview table between them', caption: '서윤은 처음으로 면접 질문을 되받았다.', characterKey: 'seoyoon', text: '그럼 묻겠습니다. 당신은 아직도 사람 쉽게 믿습니까?', direction: '조용히 되돌려주기' },
      { imageUrl: image('ex-interviewer', 14), visual: 'Doha stunned, soft light on his face, silence in meeting room', caption: '도하는 자신이 던졌던 질문에 갇혔다.', characterKey: 'doha', text: '아니요. 한 사람 때문에 배웠습니다.', direction: '작게 인정하듯' },
      { imageUrl: image('ex-interviewer', 15), visual: 'Seoyoon stands to leave, holding bag, doorway light behind her', caption: '면접은 끝났지만, 대답은 아직 남아 있었다.', characterKey: 'seoyoon', text: '그럼 이번엔 제대로 들어요. 저는 합격할 겁니다.', direction: '담담하게 선언' },
      { imageUrl: image('ex-interviewer', 16), visual: 'Doha follows her to the door, not crossing the line, regretful posture', caption: '도하는 문 앞에서 더 이상 붙잡지 못했다.', characterKey: 'doha', text: '면접 결과와 별개로... 사과하고 싶습니다.', direction: '조심스럽고 느리게' },
      { imageUrl: image('ex-interviewer', 17), visual: 'Seoyoon stops halfway through the door, profile view', caption: '서윤은 뒤돌아보지 않고 멈췄다.', characterKey: 'seoyoon', text: '사과는 늦어도 돼요. 대신 거짓말은 늦으면 안 돼요.', direction: '등 돌린 채 차갑게' },
      { imageUrl: image('ex-interviewer', 18), visual: 'Doha deletes an evaluation note and starts again, close-up no readable text', caption: '도하는 평가표를 처음부터 다시 썼다.', characterKey: 'doha', text: '지원자 한서윤. 위기 대응 능력, 최상.', direction: '면접관 톤으로 돌아오기' },
      { imageUrl: image('ex-interviewer', 19), visual: 'Seoyoon in elevator, phone notification glow, expression unreadable', caption: '엘리베이터 문이 닫히기 직전, 결과 알림이 떴다.', characterKey: 'seoyoon', text: '이제 도망칠 차례는 내가 아니야.', direction: '혼잣말처럼 낮게' },
      { imageUrl: image('ex-interviewer', 20), visual: 'Doha alone in interview room, envelope on table, sunset city behind him', caption: '빈 면접실에는 늦은 사과와 낡은 편지만 남았다.', characterKey: 'doha', text: '이번엔 내가 기다리겠습니다.', direction: '아주 작게, 후회하며' }
    ]
  },
  {
    slug: 'borrowed-tomorrow',
    title: '내일을 빌린 아이',
    logline: '내일 날짜가 찍힌 깨진 휴대폰을 주운 여고생이 하루를 바꾸려 한다.',
    maxSeconds: 58,
    thumbnailUrl: image('borrowed-tomorrow', 1),
    characters: [
      { key: 'yena', name: '예나', description: '18세. 네이비 교복과 묶은 머리. 무서워도 먼저 뛰어드는 학생.', voiceGuide: '빠르고 숨이 찬 톤. 중요한 말은 낮춰서 진심을 만든다.', color: '#5cc8ba', visual: 'Korean high school girl, 18, neat ponytail, navy school uniform, cracked phone, determined anxious eyes' },
      { key: 'jun', name: '준', description: '18세. 은테 안경을 쓴 같은 반 친구. 농담으로 불안을 숨긴다.', voiceGuide: '가볍게 시작하지만 중간부터 진지해진다.', color: '#f0bd62', visual: 'Korean high school boy, 18, silver-rim glasses, navy uniform, warm smile hiding fear' }
    ],
    cuts: [
      { imageUrl: image('borrowed-tomorrow', 1), visual: 'dawn subway platform, Yena holds cracked phone, empty train beside her', caption: '새벽 플랫폼. 예나는 내일 날짜가 뜬 휴대폰을 들고 있었다.', characterKey: 'yena', text: '이거... 오늘이 아니라 내일이잖아.', direction: '믿기지 않아 작게' },
      { imageUrl: image('borrowed-tomorrow', 2), visual: 'Yena running through crowded school hallway toward Jun', caption: '예나는 복도를 가로질러 준이 문을 열기 전에 붙잡으려 했다.', characterKey: 'yena', text: '준아, 그 문 열지 마. 오늘은 네가 다쳐.', direction: '숨차게, 급하게' },
      { imageUrl: image('borrowed-tomorrow', 3), visual: 'Jun half laughing in front of classroom door, confused classmates blurred', caption: '준은 농담처럼 웃었지만 예나의 손은 떨리고 있었다.', characterKey: 'jun', text: '너 어제 밤새 미래라도 보고 왔냐?', direction: '가볍게 시작' },
      { imageUrl: image('borrowed-tomorrow', 4), visual: 'classroom door opens, falling cleaning bucket frozen midair, Yena pulls Jun back', caption: '문 위의 양동이가 떨어지기 직전, 예나가 준을 끌어당겼다.', characterKey: 'yena', text: '봤지? 장난 아니라고 했잖아.', direction: '놀람 뒤 바로 낮게' },
      { imageUrl: image('borrowed-tomorrow', 5), visual: 'music room piano with warning sticky notes, both students shocked', caption: '음악실 피아노 위에는 누군가 남긴 경고 메모들이 놓여 있었다.', characterKey: 'jun', text: '너만 본 게 아니었네. 누가 우리보다 먼저 반복한 거야.', direction: '농담기를 빼고' },
      { imageUrl: image('borrowed-tomorrow', 6), visual: 'close-up cracked phone showing glowing tomorrow-like calendar without readable text', caption: '깨진 화면은 다음 사고 시간을 조용히 비추고 있었다.', characterKey: 'yena', text: '다음은 오후 네 시, 체육관 뒤야.', direction: '작고 빠르게' },
      { imageUrl: image('borrowed-tomorrow', 7), visual: 'school gym back alley, bicycle wheel spinning, students running past', caption: '체육관 뒤편에서 자전거가 혼자 쓰러졌다.', characterKey: 'jun', text: '이 정도면 휴대폰이 아니라 예언서인데?', direction: '무서움을 농담으로' },
      { imageUrl: image('borrowed-tomorrow', 8), visual: 'Yena finds another cracked phone reflection in window, eerie duplicate', caption: '창문에 비친 휴대폰 화면은 하나가 아니었다.', characterKey: 'yena', text: '잠깐... 이걸 가진 사람이 또 있어.', direction: '소름 돋은 듯이' },
      { imageUrl: image('borrowed-tomorrow', 9), visual: 'library aisle, mysterious senior silhouette leaves note on shelf', caption: '도서관 책장 사이로 누군가 쪽지를 남기고 사라졌다.', characterKey: 'jun', text: '따라가자. 이번엔 우리가 먼저 물어봐야 해.', direction: '진지하게 결심' },
      { imageUrl: image('borrowed-tomorrow', 10), visual: 'stairwell chase, Yena and Jun rush upstairs, sunset through windows', caption: '계단 끝에서 발소리가 멈췄다.', characterKey: 'yena', text: '도망치는 게 아니라 우리를 부르는 거야.', direction: '확신하며' },
      { imageUrl: image('borrowed-tomorrow', 11), visual: 'rooftop door cracked open, wind lifts papers around them', caption: '옥상 문 너머에는 같은 날짜가 적힌 종이들이 흩어져 있었다.', characterKey: 'jun', text: '이 학교, 내일을 몇 번이나 빌린 거야?', direction: '낮게 질린 톤' },
      { imageUrl: image('borrowed-tomorrow', 12), visual: 'Yena sees her own name on warning board, emotional close-up', caption: '경고 목록의 마지막 이름은 예나였다.', characterKey: 'yena', text: '마지막 사고가... 나라고?', direction: '말끝이 흔들리게' },
      { imageUrl: image('borrowed-tomorrow', 13), visual: 'Jun grabs Yena wrist, rooftop wind, city below', caption: '준은 처음으로 예나를 붙잡고 놓지 않았다.', characterKey: 'jun', text: '그럼 오늘은 내가 바꿀 차례네.', direction: '가볍지만 단단하게' },
      { imageUrl: image('borrowed-tomorrow', 14), visual: 'phone alarm glow, Yena decides, close shot of thumb hovering over power button', caption: '휴대폰은 다시 내일을 보여주려 했다.', characterKey: 'yena', text: '미래를 계속 보면, 현재를 못 믿게 돼.', direction: '천천히 깨닫듯' },
      { imageUrl: image('borrowed-tomorrow', 15), visual: 'school gate at dusk, students evacuating, Yena and Jun run opposite direction', caption: '모두가 나가는 동안 두 사람은 반대로 뛰었다.', characterKey: 'jun', text: '그래도 위험한 쪽으로 가는 건 변함없네.', direction: '숨차게 웃으며' },
      { imageUrl: image('borrowed-tomorrow', 16), visual: 'old broadcasting room, broken speaker sparks, hidden phone charging', caption: '방송실 안에서 또 다른 휴대폰이 충전되고 있었다.', characterKey: 'yena', text: '이게 원본이야. 내일을 보내는 쪽.', direction: '긴장해서 낮게' },
      { imageUrl: image('borrowed-tomorrow', 17), visual: 'Jun pulls cable, sparks, Yena shields him with school bag', caption: '준이 케이블을 뽑자 스피커가 터질 듯 울렸다.', characterKey: 'jun', text: '오늘은 여기서 끝내자!', direction: '크게 외침' },
      { imageUrl: image('borrowed-tomorrow', 18), visual: 'Yena drops cracked phone from pedestrian bridge at sunset', caption: '해질녘 보도교. 예나는 휴대폰을 놓아버리려 했다.', characterKey: 'yena', text: '내일을 고치려다 오늘의 너를 잃는 건 싫어.', direction: '떨리지만 또렷하게' },
      { imageUrl: image('borrowed-tomorrow', 19), visual: 'phone falls toward traffic lights below, reflected sunset', caption: '깨진 화면은 떨어지며 처음으로 꺼졌다.', characterKey: 'jun', text: '그럼 내일은 그냥 같이 맞자.', direction: '작고 따뜻하게' },
      { imageUrl: image('borrowed-tomorrow', 20), visual: 'next morning school platform, Yena and Jun stand together, no phone glow', caption: '다음 아침, 플랫폼에는 더 이상 내일이 없었다.', characterKey: 'yena', text: '오늘이 이렇게 무서운 줄 몰랐어. 그래도 좋아.', direction: '안도하며 웃음' }
    ]
  },
  {
    slug: 'moonlit-audit',
    title: '달빛 감사관',
    logline: '한밤중 기록보관소에서 시작된 감사는 도시 전체의 비밀로 이어진다.',
    maxSeconds: 60,
    thumbnailUrl: image('moonlit-audit', 1),
    characters: [
      { key: 'arin', name: '아린', description: '29세. 베이지 트렌치코트를 입은 시청 감사관. 원칙적이지만 위험을 감수한다.', voiceGuide: '정확하고 차갑게. 감정은 짧은 침묵 뒤에 드러난다.', color: '#c8a36a', visual: 'Korean municipal auditor woman, 29, beige trench coat, low ponytail, blue evidence envelope, precise cold gaze' },
      { key: 'taeoh', name: '태오', description: '32세. 야간 경비원. 평범해 보이지만 기록보관소의 진실을 알고 있다.', voiceGuide: '조용하고 느리게. 아는 것이 많지만 바로 말하지 않는다.', color: '#5c7d72', visual: 'Korean night security guard man, 32, dark green uniform, round glasses, quiet guarded expression' }
    ],
    cuts: [
      { imageUrl: image('moonlit-audit', 1), visual: 'midnight archive hallway, Arin holds sealed blue evidence envelope', caption: '비 내리는 자정, 아린은 봉인된 파란 봉투를 들고 기록실로 들어갔다.', characterKey: 'arin', text: '오늘 밤 이 문서가 사라지면, 내 이름도 같이 지워지겠죠.', direction: '차분하지만 압박감 있게' },
      { imageUrl: image('moonlit-audit', 2), visual: 'Taeoh blocks archive exit with key ring, rainy window reflections', caption: '출구를 막아선 태오는 열쇠를 흔들며 아린을 바라봤다.', characterKey: 'taeoh', text: '나가려면 봉투는 두고 가요. 그게 당신을 살리는 길입니다.', direction: '협박 같지만 걱정 섞이게' },
      { imageUrl: image('moonlit-audit', 3), visual: 'Arin steps closer in narrow shelves, blue envelope tight in hand', caption: '아린은 한 걸음도 물러서지 않았다.', characterKey: 'arin', text: '살리는 길이 아니라 숨기는 길이겠죠.', direction: '또렷하고 차갑게' },
      { imageUrl: image('moonlit-audit', 4), visual: 'security monitor wall shows archive camera feeds, Taeoh glances at blind spot', caption: '태오의 시선은 감시카메라 사각지대로 향했다.', characterKey: 'taeoh', text: '카메라가 꺼지는 시간은 90초뿐입니다.', direction: '작게, 빠르게' },
      { imageUrl: image('moonlit-audit', 5), visual: 'both run through archive aisle as fluorescent lights flicker', caption: '불이 깜빡이는 사이, 두 사람은 기록실 안쪽으로 뛰었다.', characterKey: 'arin', text: '처음부터 도와주려던 거였어요?', direction: '숨차게 의심하며' },
      { imageUrl: image('moonlit-audit', 6), visual: 'Taeoh unlocks old cabinet, dust and folders spill out', caption: '낡은 캐비닛 안에는 사라진 민원 파일들이 있었다.', characterKey: 'taeoh', text: '도와주려면 먼저 당신이 끝까지 갈 사람인지 봐야 했어요.', direction: '느리지만 단단하게' },
      { imageUrl: image('moonlit-audit', 7), visual: 'Arin discovers missing district seal on document, close-up no readable text', caption: '문서의 직인은 있어야 할 구역에서 빠져 있었다.', characterKey: 'arin', text: '이건 회계 문제가 아니야. 구역 자체가 팔렸어.', direction: '낮게 분노를 눌러서' },
      { imageUrl: image('moonlit-audit', 8), visual: 'old photocopier opens hidden compartment, memory card and torn map', caption: '낡은 복사기 안쪽에서 메모리카드와 찢어진 지도가 발견됐다.', characterKey: 'taeoh', text: '그걸 찾은 사람이 셋 있었고, 둘은 사라졌습니다.', direction: '죄책감 있게' },
      { imageUrl: image('moonlit-audit', 9), visual: 'Arin puts memory card into phone, blue glow on her face', caption: '메모리카드 안에는 시장실 통화 녹음이 남아 있었다.', characterKey: 'arin', text: '셋째는 당신이군요.', direction: '확신하며' },
      { imageUrl: image('moonlit-audit', 10), visual: 'Taeoh avoids eye contact under cold fluorescent light', caption: '태오는 대답 대신 경비모를 벗었다.', characterKey: 'taeoh', text: '증언하려다 가족 주소가 먼저 도착했습니다.', direction: '낮고 부끄럽게' },
      { imageUrl: image('moonlit-audit', 11), visual: 'archive alarm red light, both turn toward door', caption: '경보음이 기록실을 찢고 울렸다.', characterKey: 'arin', text: '이제 숨을 시간은 끝났어요.', direction: '단호하게' },
      { imageUrl: image('moonlit-audit', 12), visual: 'they push heavy archive cart to block door', caption: '두 사람은 서류 카트로 문을 막았다.', characterKey: 'taeoh', text: '옥상 송신기는 아직 살아 있습니다.', direction: '급하지만 침착하게' },
      { imageUrl: image('moonlit-audit', 13), visual: 'dark emergency stairs, Arin leads with envelope, Taeoh behind', caption: '비상계단에는 누군가의 발소리가 따라붙었다.', characterKey: 'arin', text: '따라오는 사람, 시청 직원이 아니죠?', direction: '달리며 낮게' },
      { imageUrl: image('moonlit-audit', 14), visual: 'Taeoh holds stairwell door shut as shadow approaches', caption: '태오는 문을 막고 아린에게 먼저 올라가라 손짓했다.', characterKey: 'taeoh', text: '이번엔 제가 남겠습니다. 전에도 그래야 했어요.', direction: '후회와 결심' },
      { imageUrl: image('moonlit-audit', 15), visual: 'Arin refuses, grabs his sleeve, harsh emergency light', caption: '아린은 그의 소매를 붙잡았다.', characterKey: 'arin', text: '증인은 혼자 남기면 또 사라집니다.', direction: '날카롭게 막기' },
      { imageUrl: image('moonlit-audit', 16), visual: 'rooftop door bursts open into rain before dawn', caption: '옥상 문이 열리자 새벽비가 얼굴을 때렸다.', characterKey: 'taeoh', text: '송신까지 30초. 중간에 끊기면 끝입니다.', direction: '긴박하게' },
      { imageUrl: image('moonlit-audit', 17), visual: 'Arin connects memory card to rooftop antenna box', caption: '아린은 떨리는 손으로 메모리카드를 연결했다.', characterKey: 'arin', text: '감사 결과를 시민에게 직접 송부합니다.', direction: '공식 발표처럼' },
      { imageUrl: image('moonlit-audit', 18), visual: 'city lights flicker as evidence uploads, sunrise line on horizon', caption: '도시의 불빛이 하나씩 깜빡였다.', characterKey: 'taeoh', text: '저 불이 꺼지기 전에 공개해야 합니다.', direction: '단단하게' },
      { imageUrl: image('moonlit-audit', 19), visual: 'Arin faces approaching silhouettes on rooftop, envelope in wind', caption: '검은 우산들이 옥상 입구에 나타났다.', characterKey: 'arin', text: '늦었습니다. 이미 전송됐어요.', direction: '차갑게 승리 선언' },
      { imageUrl: image('moonlit-audit', 20), visual: 'dawn rooftop, Arin and Taeoh look over city as sirens approach', caption: '새벽이 밝자, 도시가 처음으로 대답했다.', characterKey: 'taeoh', text: '달빛에 숨긴 건, 결국 아침에 드러나는군요.', direction: '조용히 안도' }
    ]
  },
  {
    slug: 'last-delivery',
    title: '마지막 배송',
    logline: '비 오는 밤, 배달 라이더가 받은 검은 상자는 누군가의 삶을 바꿀 증거였다.',
    maxSeconds: 57,
    thumbnailUrl: image('last-delivery', 1),
    characters: [
      { key: 'mira', name: '미라', description: '31세. 빨간 우비를 입은 배달 라이더. 거칠지만 약한 사람을 지나치지 못한다.', voiceGuide: '짧고 툭 던지듯 말한다. 중요한 순간엔 목소리가 낮아진다.', color: '#ef6f5e', visual: 'Korean delivery rider woman, early 30s, red rain jacket, scooter helmet, tough tired eyes, black delivery box' },
      { key: 'hyun', name: '현우', description: '34세. 지친 회사원. 검은 상자의 정체를 알고 두려워한다.', voiceGuide: '처음엔 소심하게, 점점 절박하게 올라간다.', color: '#31435f', visual: 'Korean office worker man, 34, loosened tie, exhausted face, nervous posture' }
    ],
    cuts: [
      { imageUrl: image('last-delivery', 1), visual: 'neon rainy alley, Mira on scooter holding black box with blank silver seal', caption: '네온이 번지는 골목, 미라는 은색 봉인이 붙은 검은 상자를 받았다.', characterKey: 'mira', text: '주소도 없고, 받는 사람도 없고... 돈은 두 배라.', direction: '비웃듯이 낮게' },
      { imageUrl: image('last-delivery', 2), visual: 'deserted convenience store, Hyun steps back after seeing black box', caption: '편의점에서 상자를 본 현우는 한 걸음 뒤로 물러났다.', characterKey: 'hyun', text: '그거 열면 안 됩니다. 그 안에 제 인생이 들어 있어요.', direction: '겁먹었지만 급하게' },
      { imageUrl: image('last-delivery', 3), visual: 'Mira places black box on convenience store counter, fluorescent lights', caption: '미라는 상자를 계산대 위에 내려놓았다.', characterKey: 'mira', text: '그럼 더 열어봐야겠네. 사람 인생은 배송 금지 품목이라.', direction: '툭 던지듯' },
      { imageUrl: image('last-delivery', 4), visual: 'Hyun grabs receipt from trash, security camera reflection', caption: '현우는 구겨진 영수증을 꺼내며 주변을 살폈다.', characterKey: 'hyun', text: '그 상자 때문에 세 명이 해고됐고, 한 명은 사라졌어요.', direction: '작게 떨며' },
      { imageUrl: image('last-delivery', 5), visual: 'black car headlights at alley entrance, rain reflections', caption: '골목 입구에 검은 차의 전조등이 멈췄다.', characterKey: 'mira', text: '좋아. 이제 받는 사람이 생겼네.', direction: '위험을 눈치채고 낮게' },
      { imageUrl: image('last-delivery', 6), visual: 'Mira pulls Hyun behind snack aisle as men enter store', caption: '정장을 입은 남자들이 편의점으로 들어왔다.', characterKey: 'hyun', text: '나 때문에 엮이면 안 됩니다.', direction: '절박하게 속삭임' },
      { imageUrl: image('last-delivery', 7), visual: 'Mira smirks, puts helmet on, grabs box', caption: '미라는 헬멧을 쓰며 상자를 다시 품에 안았다.', characterKey: 'mira', text: '이미 배차 떴어. 취소 수수료 비싸.', direction: '가볍게 받아치기' },
      { imageUrl: image('last-delivery', 8), visual: 'scooter bursts through rainy alley, Hyun riding behind scared', caption: '스쿠터가 빗물 고인 골목을 가르며 튀어나갔다.', characterKey: 'hyun', text: '어디로 가는 겁니까?', direction: '소리치듯' },
      { imageUrl: image('last-delivery', 9), visual: 'Mira driving scooter through neon Seoul streets, black car following', caption: '검은 차는 신호를 무시하고 따라붙었다.', characterKey: 'mira', text: '받는 사람 없는 물건은, 보내는 사람한테 돌려줘야지.', direction: '단호하게' },
      { imageUrl: image('last-delivery', 10), visual: 'under bus stop roof, Mira opens black box, tiny projector glow', caption: '버스정류장 아래, 상자 속 작은 프로젝터가 켜졌다.', characterKey: 'mira', text: '협박장인 줄 알았는데... 이건 구조 요청이네.', direction: '놀람을 누르고' },
      { imageUrl: image('last-delivery', 11), visual: 'holographic family photo glow without readable text, Hyun crying', caption: '빛 속에는 현우가 숨기려던 가족사진이 떠올랐다.', characterKey: 'hyun', text: '저걸 공개하면 제 가족이 위험해집니다.', direction: '무너질 듯이' },
      { imageUrl: image('last-delivery', 12), visual: 'Mira studies hidden data chip inside box, rain dripping from hood', caption: '사진 뒤에는 회사 비자금 서버의 접속키가 숨겨져 있었다.', characterKey: 'mira', text: '위험한 건 당신 가족이 아니라 저 사람들이네.', direction: '낮고 차갑게' },
      { imageUrl: image('last-delivery', 13), visual: 'they enter old parcel warehouse, stacked boxes, blue night light', caption: '미라는 오래된 택배 창고로 스쿠터를 몰았다.', characterKey: 'hyun', text: '여긴 왜요?', direction: '불안하게' },
      { imageUrl: image('last-delivery', 14), visual: 'Mira opens locker full of undelivered packages', caption: '창고 안에는 배달되지 못한 상자들이 빼곡했다.', characterKey: 'mira', text: '나도 한 번 못 받은 게 있어서.', direction: '짧게, 감정 숨김' },
      { imageUrl: image('last-delivery', 15), visual: 'flashback-like parcel label with Mira name blurred, her clenched fist', caption: '미라의 손이 오래된 송장 앞에서 멈췄다.', characterKey: 'mira', text: '그때도 누가 증거를 배달하다 사라졌거든.', direction: '아주 낮게' },
      { imageUrl: image('last-delivery', 16), visual: 'black car men break warehouse gate, rain and headlights', caption: '창고 문이 부서지며 검은 우산들이 들어왔다.', characterKey: 'hyun', text: '미라 씨, 이제 진짜 끝입니다.', direction: '포기한 듯' },
      { imageUrl: image('last-delivery', 17), visual: 'Mira connects box projector to warehouse broadcast monitor', caption: '미라는 상자를 창고 방송 장치에 연결했다.', characterKey: 'mira', text: '배송은 끝까지 가야 끝이야.', direction: '힘 있게' },
      { imageUrl: image('last-delivery', 18), visual: 'screens in warehouse light up with evidence glow, men freeze', caption: '창고의 모든 화면에 증거 영상이 동시에 떠올랐다.', characterKey: 'hyun', text: '이제... 숨길 수 없겠네요.', direction: '눈물 섞인 안도' },
      { imageUrl: image('last-delivery', 19), visual: 'Han River before sunrise, Mira hides box behind back facing black car', caption: '한강변 새벽, 검은 차가 마지막으로 길을 막았다.', characterKey: 'mira', text: '배송 완료는 내가 정해. 오늘은 당신들한테 안 가.', direction: '단호하고 짧게' },
      { imageUrl: image('last-delivery', 20), visual: 'sunrise over Han River, Mira rides away, Hyun watches police lights', caption: '해가 뜨자, 미라의 마지막 배송은 뉴스가 되었다.', characterKey: 'mira', text: '다음 주소는 경찰서. 요금은 선불로 받았고.', direction: '피곤하게 웃으며' }
    ]
  }
];
