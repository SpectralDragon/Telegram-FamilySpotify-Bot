import Vapor
import FluentSQLite

/// Called before your application initializes.
public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {
    /// Setting up HTTPServer
    let serverConfig = NIOServerConfig.default(hostname: "127.0.0.1", port: 9090)
    services.register(serverConfig)
    
    var middlewareConfig = MiddlewareConfig()
    middlewareConfig.use(ErrorMiddleware.self)
    middlewareConfig.use(SessionsMiddleware.self)
    services.register(middlewareConfig)
    
    ///Registering bot as a vapor service
    services.register(AdaSpotifyBot.self)
    
    try services.register(FluentSQLiteProvider())
    
    ///Registering vapor routes
    let router = EngineRouter.default()
    try routes(router)
    services.register(router, as: Router.self)
    
    var config = DatabasesConfig()
    //.file(path: "spotify-db")
    try config.add(database: SQLiteDatabase(storage: .memory), as: .sqlite)
    services.register(config)
    
    var migrations = MigrationConfig()
    migrations.add(model: Member.self, database: .sqlite)
    migrations.add(model: Family.self, database: .sqlite)
    migrations.add(model: House.self, database: .sqlite)
    services.register(migrations)
}
