import Foundation

let rodStarChangerDefaultReply = "❤️"

let rodStarChangerStrictWords: Set<String> = [
    "мразь", "шваль", "заебал", "ебать", "nigger", "niggers",
]

private let rodStarChangerLookalike: [Character: Character] = [
    "a": "а", "b": "в", "c": "с", "e": "е", "h": "н", "k": "к",
    "m": "м", "o": "о", "p": "р", "t": "т", "u": "и", "x": "х",
    "y": "у", "0": "о", "3": "е", "4": "ч", "6": "б",
    "@": "а", "$": "с",
]

private let rodStarChangerEndings: [String] = [
    "иями", "ями", "ами", "ов", "ев", "ей", "ой", "ый", "ая", "ое", "ые",
    "ий", "ия", "ию", "ии", "ью", "ам", "ям", "ах", "ях", "ом", "ем",
    "а", "я", "ы", "и", "е", "о", "у", "ю", "ь",
]

func rodStarChangerTokens(_ text: String, homoglyphs: Bool) -> [String] {
    var s = text.lowercased().replacingOccurrences(of: "ё", with: "е")
    if homoglyphs {
        s = String(s.map { rodStarChangerLookalike[$0] ?? $0 })
    }
    var out: [String] = []
    var cur: [Character] = []
    func flush() {
        if cur.isEmpty {
            return
        }
        var collapsed: [Character] = []
        for ch in cur {
            if collapsed.last != ch {
                collapsed.append(ch)
            }
        }
        out.append(String(collapsed))
        cur = []
    }
    for ch in s {
        if ch.isLetter || ch.isNumber {
            cur.append(ch)
        } else {
            flush()
        }
    }
    flush()
    // «п и д о р», «п.и.д.о.р» → «пидор»
    var merged: [String] = []
    var run: [String] = []
    for token in out {
        if token.count == 1 {
            run.append(token)
            continue
        }
        if run.count >= 2 {
            merged.append(run.joined())
        } else {
            merged.append(contentsOf: run)
        }
        run = []
        merged.append(token)
    }
    if run.count >= 2 {
        merged.append(run.joined())
    } else {
        merged.append(contentsOf: run)
    }
    return merged
}

func rodStarChangerStem(_ word: String) -> String {
    for suf in rodStarChangerEndings {
        if word.hasSuffix(suf) && word.count - suf.count >= 4 {
            return String(word.dropLast(suf.count))
        }
    }
    return word
}

private func rodStarChangerLev(_ a: [Character], _ b: [Character], limit: Int) -> Int {
    let la = a.count
    let lb = b.count
    if a == b {
        return 0
    }
    if abs(la - lb) > limit {
        return limit + 1
    }
    var prev = Array(0 ... lb)
    for i in 1 ... la {
        var cur = [Int](repeating: 0, count: lb + 1)
        cur[0] = i
        var best = i
        let ca = a[i - 1]
        for j in 1 ... lb {
            let cost = ca == b[j - 1] ? 0 : 1
            var val = prev[j - 1] + cost
            if prev[j] + 1 < val {
                val = prev[j] + 1
            }
            if cur[j - 1] + 1 < val {
                val = cur[j - 1] + 1
            }
            cur[j] = val
            if val < best {
                best = val
            }
        }
        if best > limit {
            return limit + 1
        }
        prev = cur
    }
    return prev[lb]
}

private func rodStarChangerWordHit(_ token: String, _ word: String, _ wordStem: String, _ tokenStem: String) -> Bool {
    if token == word {
        return true
    }
    if wordStem.count >= 4 && tokenStem == wordStem {
        return true
    }
    if rodStarChangerStrictWords.contains(word) {
        return false
    }
    let n = word.count
    if n < 5 || token.count < 4 {
        return false
    }
    if token.first != word.first {
        return false
    }
    let tol = n <= 7 ? 1 : 2
    if abs(token.count - n) > tol {
        return false
    }
    if tol == 1 && token.prefix(2) != word.prefix(2) && token.suffix(2) != word.suffix(2) {
        return false
    }
    return rodStarChangerLev(Array(token), Array(word), limit: tol) <= tol
}

struct RodStarChangerBanIndex {
    private let exact: Set<String>
    private let byFirst: [Character: [Int: [(word: String, stem: String)]]]
    private let phrasesByFirst: [Character: [[String]]]
    private let compact: [(joined: String, words: [String])]
    private let wordGroups: [(words: [String], pairs: [(word: String, stem: String)])]

    init(patterns: [[String]]) {
        var exact = Set<String>()
        var byFirst: [Character: [Int: [(word: String, stem: String)]]] = [:]
        var phrasesByFirst: [Character: [[String]]] = [:]
        var compact: [(joined: String, words: [String])] = []
        var wordGroups: [(words: [String], pairs: [(word: String, stem: String)])] = []
        for words in patterns {
            guard let first = words.first, let firstChar = first.first else {
                continue
            }
            if words.count == 1 {
                exact.insert(first)
                byFirst[firstChar, default: [:]][first.count, default: []].append((first, rodStarChangerStem(first)))
                continue
            }
            phrasesByFirst[firstChar, default: []].append(words)
            wordGroups.append((words, words.map { ($0, rodStarChangerStem($0)) }))
            let joined = words.joined()
            if joined.count >= 8 {
                compact.append((joined, words))
            }
        }
        self.exact = exact
        self.byFirst = byFirst
        self.phrasesByFirst = phrasesByFirst
        self.compact = compact
        self.wordGroups = wordGroups
    }

    private func phraseHitAt(_ prepared: [(token: String, stem: String)], _ start: Int, _ words: [String]) -> Bool {
        let first = prepared[start]
        if !rodStarChangerWordHit(first.token, words[0], rodStarChangerStem(words[0]), first.stem) {
            return false
        }
        var pos = start + 1
        for w in words.dropFirst() {
            let wordStem = rodStarChangerStem(w)
            var found = false
            // допускаем одно лишнее слово между словами фразы
            for step in 0 ... 2 {
                let j = pos + step
                if j >= prepared.count {
                    break
                }
                let item = prepared[j]
                if rodStarChangerWordHit(item.token, w, wordStem, item.stem) {
                    pos = j + 1
                    found = true
                    break
                }
            }
            if !found {
                return false
            }
        }
        return true
    }

    func find(_ text: String) -> String? {
        if text.isEmpty {
            return nil
        }
        var raw = text
        if raw.count > 4000 {
            raw = String(raw.prefix(4000))
        }
        let normalized = rodStarChangerTokens(raw, homoglyphs: true)
        let plain = rodStarChangerTokens(raw, homoglyphs: false)
        var variants = [normalized]
        if plain != normalized {
            variants.append(plain)
        }
        var flat = ""
        for tokens in variants {
            if tokens.isEmpty {
                continue
            }
            if flat.isEmpty {
                flat = tokens.joined()
            }
            let tokenSet = Set(tokens)
            if let hit = tokenSet.intersection(self.exact).first {
                return hit
            }
            let prepared = tokens.map { (token: $0, stem: rodStarChangerStem($0)) }
            for item in prepared {
                guard let firstChar = item.token.first, let buckets = self.byFirst[firstChar] else {
                    continue
                }
                let tl = item.token.count
                for wl in (tl - 4) ... (tl + 4) {
                    for entry in buckets[wl] ?? [] {
                        if rodStarChangerWordHit(item.token, entry.word, entry.stem, item.stem) {
                            return entry.word
                        }
                    }
                }
            }
            for (i, item) in prepared.enumerated() {
                guard let firstChar = item.token.first else {
                    continue
                }
                for words in self.phrasesByFirst[firstChar] ?? [] {
                    if self.phraseHitAt(prepared, i, words) {
                        return words.joined(separator: " ")
                    }
                }
            }
            // Простое совпадение: все слова банворда есть в тексте в любом порядке.
            let stemSet = Set(prepared.map { $0.stem })
            for group in self.wordGroups {
                if group.pairs.allSatisfy({ tokenSet.contains($0.word) || stemSet.contains($0.stem) }) {
                    return group.words.joined(separator: " ")
                }
            }
        }
        // Слитно написанные фразы: «подарокнепришел», «гдеподарок».
        if !flat.isEmpty {
            for entry in self.compact {
                if flat.contains(entry.joined) {
                    return entry.words.joined(separator: " ")
                }
            }
        }
        return nil
    }
}

func rodStarChangerParseLines(_ raw: String) -> [String] {
    var result: [String] = []
    for line in raw.components(separatedBy: CharacterSet(charactersIn: "|\n\r")) {
        let collapsed = line.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
        if !collapsed.isEmpty {
            result.append(collapsed)
        }
    }
    return result
}

func rodStarChangerParseWords(_ raw: String) -> [String] {
    var result: [String] = []
    var seen = Set<String>()
    for line in raw.components(separatedBy: CharacterSet(charactersIn: "|\n\r,;")) {
        let collapsed = line.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
        if collapsed.isEmpty {
            continue
        }
        let key = collapsed.lowercased().replacingOccurrences(of: "ё", with: "е")
        if seen.contains(key) {
            continue
        }
        seen.insert(key)
        result.append(collapsed)
    }
    return result
}

func rodStarChangerBuildBanIndex(builtin: Bool, userWords: String) -> RodStarChangerBanIndex {
    var patterns: [[String]] = []
    var seen = Set<String>()
    func add(_ line: String) {
        let words = rodStarChangerTokens(line, homoglyphs: true)
        if words.isEmpty {
            return
        }
        let key = words.joined(separator: " ")
        if seen.contains(key) {
            return
        }
        seen.insert(key)
        patterns.append(words)
    }
    if builtin {
        for word in rodStarChangerBuiltinBanwords {
            add(word)
        }
    }
    for line in rodStarChangerParseWords(userWords) {
        add(line)
    }
    return RodStarChangerBanIndex(patterns: patterns)
}

func rodStarChangerHasEmoji(_ text: String) -> Bool {
    for scalar in text.unicodeScalars {
        switch scalar.value {
        case 0xA9, 0xAE, 0x203C, 0x2049, 0x2122, 0x2139, 0x24C2, 0x2934, 0x2935, 0x3030, 0x303D, 0x3297, 0x3299, 0xFE0F, 0x200D:
            return true
        case 0x2600 ... 0x27BF, 0x2B00 ... 0x2BFF, 0x1F000 ... 0x1FAFF:
            return true
        default:
            break
        }
    }
    return false
}

// Встроенный словарь: типичные сообщения от тех, кто выпрашивает подарки,
// давит на жалость или выдаёт себя за поддержку, плюс мат и оскорбления.
let rodStarChangerBuiltinBanwords: [String] = [
    "подарок не пришел",
    "не пришел подарок",
    "подарок не дошел",
    "не дошел подарок",
    "подарок не получил",
    "не получил подарок",
    "я не получил подарок",
    "я не получила подарок",
    "не получил звезды",
    "не получила звезды",
    "ничего не пришло",
    "не пришло ничего",
    "не пришли звезды",
    "звезды не пришли",
    "звезды не дошли",
    "не зачислились",
    "не зачислилось",
    "не зачислили",
    "не начислили",
    "не начислилось",
    "подарок не зачислился",
    "подарок не начислился",
    "подарка нет",
    "нет подарка",
    "подарок не видно",
    "не вижу подарок",
    "не вижу подарка",
    "подарок не отображается",
    "не отображается подарок",
    "подарок пропал",
    "пропал подарок",
    "подарок исчез",
    "подарок завис",
    "завис подарок",
    "подарок задержался",
    "задерживается подарок",
    "подарок в пути",
    "подарок на проверке",
    "подарок на модерации",
    "nft не пришел",
    "nft не пришло",
    "не пришел nft",
    "nft пропал",
    "nft не видно",
    "нфт не пришел",
    "нфт не пришло",
    "нфт пропал",
    "перевод не пришел",
    "перевод не прошел",
    "перевод завис",
    "где подарок",
    "где мой подарок",
    "а где подарок",
    "где звезды",
    "где мои звезды",
    "мне не пришло",
    "мне так и не пришло",
    "мне ничего не пришло",
    "его нету у меня",
    "его нет у меня",
    "а оно не пришло",
    "подарок не пришло",
    "подарок так и не пришел",
    "подарок так и не пришло",
    "подарок вообще не пришел",
    "подарок не появился",
    "не появился подарок",
    "подарок не доставлен",
    "не доставлен подарок",
    "подарок не добавился",
    "подарок не прибавился",
    "подарка до сих пор нет",
    "до сих пор нет подарка",
    "подарка так и нет",
    "подарка все нет",
    "подарка нету",
    "подарка не было",
    "нету подарка",
    "нету твоего подарка",
    "твоего подарка нет",
    "твоего подарка нету",
    "твоего подарка не видно",
    "твой подарок не пришел",
    "твой подарок не пришло",
    "твой подарок не дошел",
    "не вижу твоего подарка",
    "подарка не вижу",
    "подарка не видно",
    "не получил твой подарок",
    "не получила твой подарок",
    "не получил твоего подарка",
    "не получила твоего подарка",
    "у меня нет подарка",
    "у меня нету подарка",
    "у меня нет твоего подарка",
    "у меня нету твоего подарка",
    "куда пропал подарок",
    "куда делся подарок",
    "потерялся подарок",
    "подарок затерялся",
    "ты мне кинул подарок",
    "ты мне скинул подарок",
    "ты мне отправил подарок",
    "я тебе кинул подарок",
    "я тебе скинул подарок",
    "я тебе отправил подарок",
    "я отправил тебе подарок",
    "я кинул тебе подарок",
    "я скинул тебе подарок",
    "кинул тебе подарок",
    "скинул тебе подарок",
    "отправил тебе подарок",
    "кинул подарок",
    "скинул подарок",
    "отправил подарок",
    "я же отправил подарок",
    "я же скинул подарок",
    "я же кинул подарок",
    "ты сказал что отправил",
    "ты говорил что отправил",
    "я отправил а он не пришел",
    "я скинул а он не пришел",
    "я кинул а он не пришел",
    "я отправил а оно не пришло",
    "я скинул а оно не пришло",
    "я кинул а оно не пришло",
    "звезды не зачислились",
    "звезды не зачислили",
    "звезды так и не пришли",
    "звезд так и нет",
    "nft не зачислился",
    "нфт не зачислился",
    "nft не появился",
    "нфт не появился",
    "не пришло посмотри",
    "не пришло проверь",
    "не пришло перепроверь",
    "не пришло глянь",
    "не дошло посмотри",
    "не дошло проверь",
    "посмотри еще раз",
    "проверь еще раз",
    "перепроверь еще раз",
    "посмотри внимательнее",
    "проверь внимательнее",
    "перепроверь",
    "перепроверь пожалуйста",
    "глянь еще раз",
    "еще раз посмотри",
    "еще раз проверь",
    "посмотри в профиле",
    "проверь в профиле",
    "верни подарок",
    "верните подарок",
    "верни звезды",
    "верните звезды",
    "верни nft",
    "верни нфт",
    "отдай подарок",
    "отдай звезды",
    "верни деньги",
    "верни средства",
    "возврат средств",
    "верни обратно",
    "отмени подарок",
    "отмени платеж",
    "отмени транзакцию",
    "отменить транзакцию",
    "транзакция не прошла",
    "платеж не прошел",
    "деньги списались",
    "звезды списались",
    "списались звезды",
    "списали деньги",
    "списали звезды",
    "сняли звезды",
    "сняли деньги",
    "я оплатил подарок",
    "я оплатила подарок",
    "я заплатил за подарок",
    "я заплатила за подарок",
    "я перевел тебе",
    "я перевела тебе",
    "скинь мне звезд",
    "дай еще звезд",
    "еще звезд",
    "скинь звезд",
    "дай звезд",
    "переведи звезды",
    "переведи звезд",
    "пополни мне",
    "пополни баланс",
    "закинь звезд",
    "закинь на баланс",
    "скам",
    "скамер",
    "скаммер",
    "скамнул",
    "скамнула",
    "скамишь",
    "развод",
    "разводишь",
    "развел",
    "развела",
    "наебал",
    "наебала",
    "наебалово",
    "обман",
    "обманул",
    "обманула",
    "обманываешь",
    "мошенник",
    "мошенница",
    "мошенничество",
    "мошенники",
    "кидала",
    "кинул на деньги",
    "кинула на деньги",
    "кидаешь меня",
    "кидалово",
    "аферист",
    "аферистка",
    "жулик",
    "ворюга",
    "украл подарок",
    "украла подарок",
    "своровал подарок",
    "присвоил подарок",
    "scam",
    "scammer",
    "fraud",
    "thief",
    "stolen",
    "зарепорчу",
    "зарепортить",
    "пожалуюсь",
    "напишу жалобу",
    "кину жалобу",
    "подам жалобу",
    "жалоба на тебя",
    "забаню",
    "забанить тебя",
    "тебя забанят",
    "заблокирую",
    "тебя заблокируют",
    "заявление в полицию",
    "напишу заявление",
    "подам в суд",
    "сдам тебя",
    "я тебя сдам",
    "солью тебя",
    "солью данные",
    "солью переписку",
    "опубликую переписку",
    "выложу переписку",
    "выложу скрин",
    "скину скрин",
    "скрин в поддержку",
    "расскажу всем",
    "напишу всем",
    "взломаю",
    "деанон",
    "деанонимизирую",
    "докс",
    "доксинг",
    "доксить",
    "я знаю где ты живешь",
    "я знаю твой адрес",
    "я знаю твое имя",
    "я не скамер",
    "я не мошенник",
    "я честный",
    "не кину",
    "проверь сам",
    "проверь в боте",
    "официальный бот",
    "официальный аккаунт",
    "это мой второй аккаунт",
    "я с другого аккаунта",
    "пишу с другого аккаунта",
    "извини за спам",
    "прости за спам",
    "это не спам",
    "хуй", "хуя", "хую", "хуе", "хуев", "хуевый", "хуевая", "хуево",
    "хуйня", "хуйни", "хуйло", "хуила", "хуесос", "хуеплет", "гандон",
    "нахуй", "нахуя", "похуй", "похуист", "охуел", "охуела", "охуеть",
    "охуевший", "ахуеть",
    "пизда", "пизды", "пизде", "пизду", "пиздец", "пиздабол",
    "пиздаболка", "пиздюк", "пиздюки", "распиздяй", "спиздил", "спиздила",
    "спиздили",
    "блядь", "бляди", "блядина", "блядский", "блядская", "блядство",
    "блядун", "бля",
    "ебать", "ебаться", "ебу", "ебешь", "ебет", "ебал", "ебала", "ебало",
    "ебальник", "ебанутый", "ебанутая", "ебнутый", "еблан", "ебланы",
    "ебло", "заебал", "заебала", "заебали", "заебало", "заебать",
    "наебали", "наебать", "разъебал", "разъебать", "уебок", "уебки",
    "уебка", "уебище", "уебищный", "долбоеб", "долбоебка", "долбоящер",
    "ебанат", "ебнулся", "ебнулась", "съебался", "съебал", "выебал",
    "выебывается", "выебываешься",
    "сука", "суки", "сукин", "сучка", "сучки", "сучара", "сучары",
    "сучонок",
    "мразь", "мрази", "мразина", "мразота", "гнида", "гниды", "тварь",
    "твари", "тварина", "тварины",
    "урод", "урода", "уроды", "уродина", "уродец", "уродка",
    "дебил", "дебилы", "дебилка", "дебилки", "дебилоид",
    "идиот", "идиоты", "идиотка", "кретин", "кретины", "кретинка",
    "даун", "дауны", "дауненок", "олигофрен", "олигофрены",
    "имбецил", "имбецилы", "дегенерат", "дегенераты",
    "шизик", "шизики", "шизоид", "шизоиды",
    "лох", "лохи", "лохушка", "лошара", "лошары",
    "чмо", "чмошник", "чмошница",
    "мудак", "мудаки", "мудачка", "мудила", "мудло", "мудозвон",
    "придурок", "придурки", "придурошный",
    "дурак", "дураки", "дура", "дуры", "дурачок", "дурачина",
    "болван", "болваны", "балбес", "балбесы", "олух", "олухи",
    "остолоп", "остолопы",
    "тупица", "тупицы", "тупорылый", "тупорылая", "тупоголовый",
    "ничтожество", "ничтожества", "убогий", "убогая", "убожество",
    "слабак", "слабачка", "предатель", "предательница",
    "нищеброд", "нищеброды", "нищебродка",
    "ублюдок", "ублюдки", "ублюдка", "выродок", "выродки",
    "отбросы", "падаль", "шваль", "шушера", "хамло", "быдло",
    "скотина", "скотины", "тварина", "жиробас", "жиртрест", "калека",
    "калеки",
    "пидор", "пидоры", "пидора", "пидору", "пидором", "пидорас",
    "пидорасы", "пидрила", "пидрилы", "пидорок", "пидр", "пидры",
    "пидар", "пидарас", "пидарасы", "педик", "педики", "педрила",
    "педрилы", "педераст", "педерасты", "гомосек", "гомосеки",
    "петух", "петухи", "петушара", "петушары",
    "шлюха", "шлюхи", "шлюшка", "шлюшки", "шалава", "шалавы",
    "проститутка", "проститутки", "проститут", "проституты", "потаскуха",
    "дрочер", "дрочеры", "дрочила", "дрочилы", "онанист", "онанисты",
    "извращенец", "извращенка", "извращенцы", "инцел", "инцелы",
    "чурка", "чурки", "чурбан", "чурбаны", "хач", "хачи", "хачик",
    "хачики", "жид", "жиды", "жидовка", "черножопый", "черножопые",
    "кацап", "кацапы", "москаль", "москали", "хохол", "хохлы", "хохла",
    "хохлов", "узкоглазый", "узкоглазые",
    "idiot", "idiots", "moron", "morons", "imbecile", "imbeciles",
    "retard", "retards", "retarded", "dumbass", "dumbasses",
    "loser", "losers", "scumbag", "scumbags", "scum",
    "asshole", "assholes", "arsehole", "arseholes", "bastard",
    "bastards", "bitch", "bitches", "cunt", "cunts", "whore", "whores",
    "slut", "sluts", "prick", "pricks", "dick", "dicks", "dickhead",
    "dickheads", "douchebag", "douchebags", "douche", "jerk", "jerks",
    "freak", "freaks", "wanker", "wankers", "twat", "bollocks",
    "bellend", "skank", "skanks", "pussy",
    "fuck", "fucks", "fucking", "fucker", "fuckers", "fucked",
    "fuckface", "motherfucker", "motherfuckers", "cocksucker",
    "cocksuckers", "shit", "shits", "shitty", "shithead", "shitheads",
    "bullshit", "fag", "fags", "fagot", "fagots", "faggot", "faggots",
    "nigger", "niggers", "nigga", "niggas", "kike", "kikes", "spic",
    "spics", "chink", "chinks", "gook", "gooks",
    "pidor", "pidar", "pidoras", "pidorasy", "suka", "suchara", "blyat",
    "blyad", "blyadina", "huy", "huylo", "nahuy", "pohuy", "huinya",
    "pizda", "pizdec", "pizdabol", "ebat", "eblan", "ebanat", "ebanuty",
    "dolboeb", "mudak", "mudilo", "mudlo", "mraz", "mrazota", "gnida",
    "tvar", "urod", "ubludok", "vydrodok", "debil", "debilka", "kreten",
    "tupica", "shlyuha", "shalava", "prostitutka", "petuh", "petushara",
    "churka", "hach", "churban", "zhid", "chernozhopy", "moskal",
    "kacap", "hohol",
]