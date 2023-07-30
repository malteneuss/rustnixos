use sqlx::postgres::PgPoolOptions;
use axum::{
    routing::{get, post},
    http::StatusCode,
    response::IntoResponse,
    Json, Router,
};
use std::net::SocketAddr;

#[tokio::main]
async fn main() {
    // initialize tracing
    tracing_subscriber::fmt::init();
    println!("Loading");
    let pool = PgPoolOptions::new()
      .max_connections(5)
      // .connect("postgres:///rustnixos").await.unwrap();
      // .connect("postgres://rustnixos:@localhost:5432/rustnixos?sslmode=disable").await.unwrap();
    .connect("postgres://rustnixos:@db-dev:5432/rustnixos?sslmode=disable").await.unwrap();

    println!("querying");
    // Make a simple query to return the given parameter (use a question mark `?` instead of `$1` for MySQL)
    let row: (i32,) = sqlx::query_as("SELECT * FROM Values")
      // .bind(150_i64)
      .fetch_one(&pool).await.unwrap();
    println!("ready {}", row.0);

    tracing::info!("loaded {}", row.0);


    // Ok(());

    // build our application with a route
    let app = Router::new()
      // `GET /` goes to `root`
      .route("/", get(root));
      // `POST /users` goes to `create_user`
      // .route("/users", post(create_user));

    let addr = SocketAddr::from(([127, 0, 0, 1], 3000));
    tracing::debug!("listening on {}", addr);
    axum::Server::bind(&addr)
      .serve(app.into_make_service())
      .await
      .unwrap();
}

// basic handler that responds with a static string
async fn root() -> &'static str {
    "<h1>Hello, World!</h1>"
}