import database
import gleam/http/request
import gleam/http/response
import gleam/option
import mist
import webproxy_server/auth
import webproxy_server/cluster
import webproxy_server/engine.{
  type WsState, Authorized, Unauthorized, Unreacheable,
}
import webproxy_server/web

pub type Database {
  Database(
    users: database.Table(auth.User),
    clusters: database.Table(cluster.Cluster),
    pending_resources: database.Table(engine.PendingResource),
  )
}

pub fn handle_request(
  request: request.Request(mist.Connection),
  db: Database,
) -> response.Response(mist.ResponseData) {
  case request.path_segments(request) {
    ["ws"] ->
      mist.websocket(
        request:,
        on_init: fn(_conn) {
          let state = case mist.get_connection_info(request.body) {
            Ok(info) ->
              engine.Unauthorized(mist.ip_address_to_string(info.ip_address))
            Error(_) -> engine.Unreacheable
          }
          #(state, option.None)
        },
        on_close: fn(_state) { Nil },
        handler: fn(state, message, conn) {
          handle_ws_message(state, message, conn, db)
        },
      )
    _ -> web.not_found()
  }
}

fn handle_ws_message(
  state: WsState,
  message: mist.WebsocketMessage(b),
  conn: mist.WebsocketConnection,
  db: Database,
) {
  case message, state {
    _, Unreacheable -> mist.stop()
    mist.Text("ping"), _ -> engine.ping(conn, state)

    mist.Text("/s " <> auth_token), Unauthorized(address) ->
      engine.subscribe(db.users, db.clusters, address, auth_token, conn)

    _, Unauthorized(_) -> mist.continue(state)

    mist.Text("/r " <> resource_name),
      Authorized(user_id:, scopes:, cluster_id:)
    ->
      engine.require(
        db.clusters,
        db.pending_resources,
        cluster_id,
        user_id,
        scopes,
        resource_name,
      )

    mist.Text("/p " <> data), Authorized(user_id:, scopes:, cluster_id:) ->
      engine.provide(
        db.clusters,
        db.pending_resources,
        cluster_id,
        user_id,
        scopes,
        data,
      )

    mist.Closed, _ | mist.Shutdown, _ -> mist.stop()

    _, _ -> mist.continue(state)
  }
}
