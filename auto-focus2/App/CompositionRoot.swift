import Foundation

struct CompositionRoot {
    let clock: Clocking

    // Domain
    let stateMachine: FocusStateMachine

    // Persistence
    let database: SQLiteDatabase
    let settingsStore: FocusSettingsStoring
    let entityStore: FocusEntityStoring
    let eventStore: FocusEventStoring
    let sessionStore: FocusSessionStoring

    // Adapters
    let foregroundProvider: ForegroundProviding
    let domainProvider: BrowserDomainProviding
    let notificationsController: NotificationsControlling
    let launchOnLoginService: LaunchOnLoginServicing

    init(appSupportDirectory: URL) throws {
        self.clock = SystemClock()
        self.stateMachine = FocusStateMachine()

        let dbURL = appSupportDirectory.appendingPathComponent("autofocus2.sqlite")
        self.database = try SQLiteDatabase(path: dbURL.path)
        try Migrations.migrate(database: database)

        self.settingsStore = SQLiteFocusSettingsStore(database: database)
        self.entityStore = SQLiteFocusEntityStore(database: database)
        self.eventStore = SQLiteFocusEventStore(database: database)
        self.sessionStore = SQLiteFocusSessionStore(database: database)

        self.foregroundProvider = ForegroundAppProvider()
        self.domainProvider = BrowserDomainProvider()
        self.notificationsController = ShortcutNotificationsController()
        self.launchOnLoginService = LaunchOnLoginService()
    }
}


