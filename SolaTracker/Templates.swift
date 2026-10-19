import Foundation

struct FieldTemplate {
    var name: String
    var kind: FieldKind
    var unit: String = ""
    var options: [String] = []
    var defaultNumber: Double? = nil
    var defaultText: String = ""
    var aggregate: Aggregate = .sum
}

struct TrackerTemplate: Identifiable {
    enum Category: CaseIterable, Identifiable {
        case health, fitness, mind, learning, everyday
        var id: Self { self }
        var label: String {
            switch self {
            case .health: String(localized: "Health")
            case .fitness: String(localized: "Fitness")
            case .mind: String(localized: "Mind")
            case .learning: String(localized: "Learning")
            case .everyday: String(localized: "Everyday")
            }
        }
    }

    let id: String
    let category: Category
    let name: String
    let symbol: String
    let colorIndex: Int
    var logMode: LogMode = .form
    var goal: Int = 0
    let fields: [FieldTemplate]

    var summary: String {
        fields.map { $0.unit.isEmpty ? $0.name : "\($0.name) (\($0.unit))" }.joined(separator: " · ")
    }
}

/// Built at call time so names come out in the current language.
enum Templates {
    static var all: [TrackerTemplate] {
        let currency = Locale.current.currencySymbol ?? "€"
        return [
            // Health
            TrackerTemplate(id: "water", category: .health, name: String(localized: "Water"), symbol: "drop.fill", colorIndex: 7, logMode: .quick, goal: 8, fields: [
                FieldTemplate(name: String(localized: "Amount"), kind: .number, unit: "ml", defaultNumber: 250),
                FieldTemplate(name: String(localized: "Drink"), kind: .choice, options: [String(localized: "Water"), String(localized: "Sparkling water"), String(localized: "Tea")], defaultText: String(localized: "Water")),
            ]),
            TrackerTemplate(id: "coffee", category: .health, name: String(localized: "Coffee"), symbol: "cup.and.saucer.fill", colorIndex: 3, logMode: .quick, fields: [
                FieldTemplate(name: String(localized: "Size"), kind: .choice, options: [String(localized: "Espresso"), String(localized: "Cup"), String(localized: "Mug")], defaultText: String(localized: "Cup")),
                FieldTemplate(name: String(localized: "Location"), kind: .text),
            ]),
            TrackerTemplate(id: "sleep", category: .health, name: String(localized: "Sleep"), symbol: "bed.double.fill", colorIndex: 5, fields: [
                FieldTemplate(name: String(localized: "Duration"), kind: .duration, defaultNumber: 450),
                FieldTemplate(name: String(localized: "Quality"), kind: .rating, aggregate: .average),
            ]),
            TrackerTemplate(id: "medication", category: .health, name: String(localized: "Medication"), symbol: "pills.fill", colorIndex: 6, logMode: .quick, fields: [
                FieldTemplate(name: String(localized: "Medication"), kind: .text),
                FieldTemplate(name: String(localized: "Dose"), kind: .number, unit: "mg"),
            ]),
            TrackerTemplate(id: "alcohol", category: .health, name: String(localized: "Alcohol"), symbol: "wineglass.fill", colorIndex: 2, fields: [
                FieldTemplate(name: String(localized: "Drink"), kind: .choice, options: [String(localized: "Beer"), String(localized: "Wine"), String(localized: "Cocktail"), String(localized: "Spirits")]),
                FieldTemplate(name: String(localized: "Amount"), kind: .number, unit: "ml", defaultNumber: 330),
                FieldTemplate(name: String(localized: "Location"), kind: .text),
                FieldTemplate(name: String(localized: "With"), kind: .text),
            ]),
            TrackerTemplate(id: "headache", category: .health, name: String(localized: "Headache"), symbol: "brain.head.profile", colorIndex: 6, fields: [
                FieldTemplate(name: String(localized: "Intensity"), kind: .rating, aggregate: .average),
                FieldTemplate(name: String(localized: "Duration"), kind: .duration),
                FieldTemplate(name: String(localized: "Took medication"), kind: .toggle),
                FieldTemplate(name: String(localized: "Trigger"), kind: .text),
            ]),
            TrackerTemplate(id: "snacks", category: .health, name: String(localized: "Sweets & snacks"), symbol: "takeoutbag.and.cup.and.straw.fill", colorIndex: 3, fields: [
                FieldTemplate(name: String(localized: "What"), kind: .text),
                FieldTemplate(name: String(localized: "Reason"), kind: .choice, options: [String(localized: "Hunger"), String(localized: "Boredom"), String(localized: "Stress"), String(localized: "Social")]),
            ]),
            // Fitness
            TrackerTemplate(id: "workout", category: .fitness, name: String(localized: "Workout"), symbol: "dumbbell.fill", colorIndex: 1, fields: [
                FieldTemplate(name: String(localized: "Type"), kind: .text),
                FieldTemplate(name: String(localized: "Duration"), kind: .duration, defaultNumber: 45),
                FieldTemplate(name: String(localized: "Intensity"), kind: .rating, aggregate: .average),
            ]),
            TrackerTemplate(id: "run", category: .fitness, name: String(localized: "Run"), symbol: "figure.run", colorIndex: 4, fields: [
                FieldTemplate(name: String(localized: "Distance"), kind: .number, unit: "km"),
                FieldTemplate(name: String(localized: "Duration"), kind: .duration, defaultNumber: 30),
                FieldTemplate(name: String(localized: "Route"), kind: .text),
            ]),
            TrackerTemplate(id: "walk", category: .fitness, name: String(localized: "Walk"), symbol: "figure.walk", colorIndex: 8, logMode: .quick, fields: [
                FieldTemplate(name: String(localized: "Duration"), kind: .duration, defaultNumber: 20),
                FieldTemplate(name: String(localized: "Location"), kind: .text),
            ]),
            TrackerTemplate(id: "yoga", category: .fitness, name: String(localized: "Yoga & stretching"), symbol: "figure.yoga", colorIndex: 5, fields: [
                FieldTemplate(name: String(localized: "Duration"), kind: .duration, defaultNumber: 15),
                FieldTemplate(name: String(localized: "Style"), kind: .choice, options: [String(localized: "Yoga"), String(localized: "Stretching"), String(localized: "Mobility")]),
            ]),
            // Mind
            TrackerTemplate(id: "meditation", category: .mind, name: String(localized: "Meditation"), symbol: "figure.mind.and.body", colorIndex: 0, logMode: .quick, goal: 1, fields: [
                FieldTemplate(name: String(localized: "Duration"), kind: .duration, defaultNumber: 10),
                FieldTemplate(name: String(localized: "Type"), kind: .choice, options: [String(localized: "Breathing"), String(localized: "Body scan"), String(localized: "Guided"), String(localized: "Silent")]),
                FieldTemplate(name: String(localized: "Source"), kind: .text),
            ]),
            TrackerTemplate(id: "mood", category: .mind, name: String(localized: "Mood"), symbol: "face.smiling", colorIndex: 3, fields: [
                FieldTemplate(name: String(localized: "Mood"), kind: .rating, aggregate: .average),
                FieldTemplate(name: String(localized: "Trigger"), kind: .text),
            ]),
            TrackerTemplate(id: "gratitude", category: .mind, name: String(localized: "Gratitude"), symbol: "heart.fill", colorIndex: 2, fields: [
                FieldTemplate(name: String(localized: "Grateful for"), kind: .text),
            ]),
            TrackerTemplate(id: "journaling", category: .mind, name: String(localized: "Journaling"), symbol: "pencil.line", colorIndex: 9, fields: [
                FieldTemplate(name: String(localized: "Duration"), kind: .duration, defaultNumber: 10),
                FieldTemplate(name: String(localized: "Topic"), kind: .text),
            ]),
            // Learning
            TrackerTemplate(id: "reading", category: .learning, name: String(localized: "Reading"), symbol: "book.fill", colorIndex: 1, fields: [
                FieldTemplate(name: String(localized: "Book"), kind: .text),
                FieldTemplate(name: String(localized: "Pages"), kind: .number, unit: String(localized: "pages")),
                FieldTemplate(name: String(localized: "Duration"), kind: .duration),
            ]),
            TrackerTemplate(id: "language", category: .learning, name: String(localized: "Language practice"), symbol: "character.bubble.fill", colorIndex: 4, fields: [
                FieldTemplate(name: String(localized: "Language"), kind: .text),
                FieldTemplate(name: String(localized: "Duration"), kind: .duration, defaultNumber: 15),
                FieldTemplate(name: String(localized: "Source"), kind: .text),
            ]),
            TrackerTemplate(id: "instrument", category: .learning, name: String(localized: "Instrument practice"), symbol: "music.note", colorIndex: 4, fields: [
                FieldTemplate(name: String(localized: "Instrument"), kind: .text),
                FieldTemplate(name: String(localized: "Duration"), kind: .duration, defaultNumber: 30),
                FieldTemplate(name: String(localized: "Piece"), kind: .text),
            ]),
            // Everyday
            TrackerTemplate(id: "socialmedia", category: .everyday, name: String(localized: "Social media"), symbol: "iphone", colorIndex: 9, fields: [
                FieldTemplate(name: String(localized: "App"), kind: .choice, options: ["Instagram", "TikTok", "YouTube", "Reddit", "X"]),
                FieldTemplate(name: String(localized: "Duration"), kind: .duration),
            ]),
            TrackerTemplate(id: "spending", category: .everyday, name: String(localized: "Spending"), symbol: "creditcard.fill", colorIndex: 8, fields: [
                FieldTemplate(name: String(localized: "Amount"), kind: .number, unit: currency),
                FieldTemplate(name: String(localized: "Category"), kind: .choice, options: [String(localized: "Groceries"), String(localized: "Eating out"), String(localized: "Transport"), String(localized: "Shopping"), String(localized: "Other")]),
                FieldTemplate(name: String(localized: "Location"), kind: .text),
            ]),
            TrackerTemplate(id: "event", category: .everyday, name: String(localized: "Event"), symbol: "number", colorIndex: 0, fields: [
                FieldTemplate(name: String(localized: "Location"), kind: .text),
                FieldTemplate(name: String(localized: "Source"), kind: .text),
                FieldTemplate(name: String(localized: "Target"), kind: .text),
            ]),
        ]
    }
}

/// Curated SF Symbols for the icon picker.
enum SymbolChoices {
    static let all = [
        "drop.fill", "cup.and.saucer.fill", "mug.fill", "wineglass.fill", "fork.knife", "takeoutbag.and.cup.and.straw.fill",
        "carrot.fill", "pills.fill", "cross.case.fill", "bed.double.fill", "brain.head.profile", "heart.fill",
        "figure.run", "figure.walk", "figure.yoga", "figure.mind.and.body", "dumbbell.fill", "bicycle",
        "book.fill", "pencil.line", "character.bubble.fill", "music.note", "paintbrush.fill", "gamecontroller.fill",
        "iphone", "tv.fill", "creditcard.fill", "cart.fill", "car.fill", "tram.fill",
        "leaf.fill", "pawprint.fill", "sun.max.fill", "moon.fill", "face.smiling", "person.2.fill",
        "phone.fill", "envelope.fill", "bolt.fill", "flame.fill", "star.fill", "number",
    ]
}
