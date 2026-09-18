use std::{
    io::{ErrorKind, Read, Write},
    net::{TcpListener, TcpStream},
    sync::{
        Arc,
        atomic::{AtomicUsize, Ordering},
    },
    thread,
    time::{Duration, Instant},
};

use crate::{
    InterpretRequest, InterpretRequestV2, InterpretResponse, ResolutionRequest, interpret,
    interpret_v2, resolve_entity,
};

const MAX_REQUEST_BYTES: usize = 65_536;
const MAX_HEADER_BYTES: usize = 8_192;
const MAX_RESPONSE_BYTES: usize = 65_536;
const MAX_CONNECTIONS: usize = 16;
const IO_TIMEOUT: Duration = Duration::from_secs(3);

const V2_INVALID_REQUEST: &[u8] = br#"{"status":"invalid_request","version":2}"#;

#[derive(Clone, Copy)]
enum Route {
    V1Interpret,
    V2Resolve,
    V2Interpret,
}

struct ConnectionGuard(Arc<AtomicUsize>);

impl Drop for ConnectionGuard {
    fn drop(&mut self) {
        self.0.fetch_sub(1, Ordering::AcqRel);
    }
}

/// Serve local requests until accepting a connection fails.
///
/// # Errors
///
/// Returns the listener error that stops the accept loop.
pub fn serve(listener: &TcpListener) -> std::io::Result<()> {
    let active = Arc::new(AtomicUsize::new(0));
    loop {
        let (mut stream, _) = listener.accept()?;
        if active.fetch_add(1, Ordering::AcqRel) >= MAX_CONNECTIONS {
            active.fetch_sub(1, Ordering::AcqRel);
            let _ = stream.set_nonblocking(true);
            let _ = write_raw(&mut stream, 503, br#"{"status":"unavailable","version":1}"#);
            continue;
        }
        let guard = ConnectionGuard(Arc::clone(&active));
        let handle = thread::Builder::new()
            .name("local-nlu-http".to_owned())
            .spawn(move || {
                let _guard = guard;
                let _ = handle_connection(&mut stream);
            })?;
        drop(handle);
    }
}

/// Accept and handle exactly one connection.
///
/// # Errors
///
/// Returns an accept, socket, parsing, or response I/O error.
pub fn serve_one(listener: &TcpListener) -> std::io::Result<()> {
    let (mut stream, _) = listener.accept()?;
    handle_connection(&mut stream)
}

fn route_error(stream: &mut TcpStream, route: Route, status: u16) -> std::io::Result<()> {
    match route {
        Route::V1Interpret => write_response(
            stream,
            status,
            &InterpretResponse::InvalidRequest { version: 1 },
        ),
        Route::V2Resolve | Route::V2Interpret => write_raw(stream, status, V2_INVALID_REQUEST),
    }
}

#[allow(clippy::too_many_lines)]
fn handle_connection(stream: &mut TcpStream) -> std::io::Result<()> {
    let deadline = Instant::now() + IO_TIMEOUT;
    stream.set_write_timeout(Some(IO_TIMEOUT))?;

    let mut received = Vec::with_capacity(1_024);
    let header_end = loop {
        let mut chunk = [0_u8; 1_024];
        let count = read_until(stream, &mut chunk, deadline)?;
        if count == 0 {
            return write_response(
                stream,
                400,
                &InterpretResponse::InvalidRequest { version: 1 },
            );
        }
        received.extend_from_slice(&chunk[..count]);
        if let Some(index) = received.windows(4).position(|window| window == b"\r\n\r\n") {
            let header_end = index + 4;
            if header_end > MAX_HEADER_BYTES {
                return write_response(
                    stream,
                    431,
                    &InterpretResponse::InvalidRequest { version: 1 },
                );
            }
            break header_end;
        }
        if received.len() >= MAX_HEADER_BYTES {
            return write_response(
                stream,
                431,
                &InterpretResponse::InvalidRequest { version: 1 },
            );
        }
    };

    let Ok(header) = std::str::from_utf8(&received[..header_end]) else {
        return write_response(
            stream,
            400,
            &InterpretResponse::InvalidRequest { version: 1 },
        );
    };
    let mut lines = header.split("\r\n");
    let request_line = lines.next().unwrap_or_default();
    if request_line == "GET /health HTTP/1.1" {
        return write_raw(stream, 200, br#"{"status":"ok","version":1}"#);
    }
    let route = if request_line == "POST /v1/interpret HTTP/1.1" {
        Route::V1Interpret
    } else if request_line == "POST /v2/resolve HTTP/1.1" {
        Route::V2Resolve
    } else if request_line == "POST /v2/interpret HTTP/1.1" {
        Route::V2Interpret
    } else {
        return write_response(
            stream,
            404,
            &InterpretResponse::InvalidRequest { version: 1 },
        );
    };

    let mut content_length = None;
    let mut content_length_seen = false;
    let mut content_type_ok = false;
    for line in lines.filter(|line| !line.is_empty()) {
        let Some((name, value)) = line.split_once(':') else {
            return route_error(stream, route, 400);
        };
        if name.eq_ignore_ascii_case("transfer-encoding") {
            return route_error(stream, route, 400);
        }
        if name.eq_ignore_ascii_case("content-length") {
            if content_length_seen {
                return route_error(stream, route, 400);
            }
            content_length_seen = true;
            let Ok(parsed) = value.trim().parse::<usize>() else {
                return route_error(stream, route, 400);
            };
            content_length = Some(parsed);
        }
        if name.eq_ignore_ascii_case("content-type")
            && value
                .trim()
                .split(';')
                .next()
                .is_some_and(|value| value.eq_ignore_ascii_case("application/json"))
        {
            content_type_ok = true;
        }
    }
    let Some(content_length) = content_length else {
        return route_error(stream, route, 411);
    };
    if !content_type_ok || content_length == 0 || content_length > MAX_REQUEST_BYTES {
        return route_error(stream, route, 400);
    }

    let already_read = received.len().saturating_sub(header_end);
    if already_read > content_length {
        return route_error(stream, route, 400);
    }
    let mut body = Vec::with_capacity(content_length);
    body.extend_from_slice(&received[header_end..]);
    body.resize(content_length, 0);
    read_exact_until(stream, &mut body[already_read..], deadline)?;

    match route {
        Route::V1Interpret => {
            let response = serde_json::from_slice::<InterpretRequest>(&body).map_or_else(
                |_| InterpretResponse::InvalidRequest { version: 1 },
                |request| interpret(&request),
            );
            write_response(stream, 200, &response)
        }
        Route::V2Resolve => {
            let Ok(request) = serde_json::from_slice::<ResolutionRequest>(&body) else {
                return route_error(stream, route, 400);
            };
            let payload =
                serde_json::to_vec(&resolve_entity(&request)).map_err(std::io::Error::other)?;
            if payload.len() > MAX_RESPONSE_BYTES {
                return route_error(stream, route, 500);
            }
            write_raw(stream, 200, &payload)
        }
        Route::V2Interpret => {
            let Ok(request) = serde_json::from_slice::<InterpretRequestV2>(&body) else {
                return route_error(stream, route, 400);
            };
            let payload =
                serde_json::to_vec(&interpret_v2(&request)).map_err(std::io::Error::other)?;
            if payload.len() > MAX_RESPONSE_BYTES {
                return route_error(stream, route, 500);
            }
            write_raw(stream, 200, &payload)
        }
    }
}

fn read_until(
    stream: &mut TcpStream,
    buffer: &mut [u8],
    deadline: Instant,
) -> std::io::Result<usize> {
    let remaining = deadline
        .checked_duration_since(Instant::now())
        .filter(|duration| !duration.is_zero())
        .ok_or_else(|| std::io::Error::new(ErrorKind::TimedOut, "request deadline"))?;
    stream.set_read_timeout(Some(remaining))?;
    stream.read(buffer)
}

fn read_exact_until(
    stream: &mut TcpStream,
    mut buffer: &mut [u8],
    deadline: Instant,
) -> std::io::Result<()> {
    while !buffer.is_empty() {
        let count = read_until(stream, buffer, deadline)?;
        if count == 0 {
            return Err(std::io::Error::new(
                ErrorKind::UnexpectedEof,
                "request body",
            ));
        }
        buffer = &mut buffer[count..];
    }
    Ok(())
}

fn write_response(
    stream: &mut TcpStream,
    status: u16,
    response: &InterpretResponse,
) -> std::io::Result<()> {
    let body = serde_json::to_vec(response).map_err(std::io::Error::other)?;
    write_raw(stream, status, &body)
}

fn write_raw(stream: &mut TcpStream, status: u16, body: &[u8]) -> std::io::Result<()> {
    if body.len() > MAX_RESPONSE_BYTES {
        return Err(std::io::Error::other("response limit"));
    }
    let reason = match status {
        200 => "OK",
        400 => "Bad Request",
        404 => "Not Found",
        411 => "Length Required",
        431 => "Request Header Fields Too Large",
        503 => "Service Unavailable",
        _ => "Error",
    };
    write!(
        stream,
        "HTTP/1.1 {status} {reason}\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n",
        body.len()
    )?;
    stream.write_all(body)?;
    stream.flush()
}
