import gleam/erlang/process
import gleam/io
import mist
import webproxy_server/auth
import webproxy_server/cluster
import webproxy_server/engine
import webproxy_server/router

pub fn main() -> Nil {
  io.println("Starting server...")

  let users = auth.new_user_table()
  let clusters = cluster.new_clusters_table()
  let pending_resources = engine.new_pending_resources_queue()
  let db = router.Database(users:, clusters:, pending_resources:)

  let assert Ok(_) =
    router.handle_request(_, db)
    |> mist.new
    |> mist.bind("0.0.0.0")
    |> mist.port(8080)
    |> mist.start

  io.println("Server started at port 8080")
  process.sleep_forever()
}
