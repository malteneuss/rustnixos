// fn main() {
//     loop {
//         println!("Hello, world!");
//     }
// }
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