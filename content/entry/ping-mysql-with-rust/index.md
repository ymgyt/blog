+++
title = "🏓 RustでMySQLにpingをうつ"
slug = "ping-mysql-with-rust"
date = "2020-02-02"
draft = false
[taxonomies]
tags = ["rust"]
+++

local環境でdocker-compose等を利用してDBを立ち上げた際に、DBの"ready"を待ちたいことがありました。  
最初は、tcp接続でよしとしていたのですが、やはりprotocol的な"ready"が必要だったので、pingをうつ必要がありました。
ということで、RustでMySQLにpingを打ち続けるCLIを作ってみました。  
[source code](https://github.com/ymgyt/mysqlpinger)


flagは以下のような感じです。
```console
$ mysqlpinger --help
mysqlpinger 0.2.1
Ping to mysql server

USAGE:
    mysqlpinger [FLAGS] [OPTIONS] [DBNAME]

ARGS:
    <DBNAME>    Database name [env: MYSQL_DB_NAME=]  [default: sys]

FLAGS:
    -s, --silent     Running with no logging
    -v, --verbose    Verbose
        --forever    Retry without limit
        --help       Prints help information
    -V, --version    Prints version information

OPTIONS:
    -h, --host <HOST>            MySQL server hostname [env: MYSQL_HOST=]  [default: 127.0.0.1]
    -p, --port <PORT>            MySQL server port [env: MYSQL_PORT=]  [default: 3306]
    -u, --user <USER>            User for authentication [env: MYSQL_USER=]  [default: root]
    -P, --pass <PASS>            Password for authentication [env: MYSQL_PASSWORD=]
    -m, --max-retry <COUNT>      Max retry count [default: 9]
    -i, --interval <DURATION>    Retry ping interval [default: 1s]

Example:
    # Basic
    mysqlpinger --pass=root --port=30303 <db_name>

    # Docker
    docker run --rm -t --network=<network> ymgyt/mysqlpinger:latest \
       --user=user --pass=secret --host=<container_name> [--forever|--max-retry=20]

```

接続のための情報とどれくらいretryするかを指定して、pingが通るまでblockします。

```console
$ docker run --rm -t --network=network  ymgyt/mysqlpinger:latest --pass=secret --host=db --forever
INFO ping -> addr:db:3306 user:root db:sys
INFO 1/♾  Connection refused (os error 111)
INFO 2/♾  Connection refused (os error 111)
// ...
INFO 30/♾  Connection refused (os error 111)
INFO 31/♾  Connection refused (os error 111)
INFO OK (elapsed 31.152sec)
```


## Connection処理
```toml
[dependencies]
lazy_static = "1.4.0"
mysql = "17.0.0"
parse_duration = "2.0"
colored = "1.9"
log = "0.4"
env_logger = "0.6"
console = "0.9.2"
ctrlc = "3.1.3"

[dependencies.clap]
git = "https://github.com/clap-rs/clap"
branch = "master"
```

```rust
use clap::ArgMatches;
use log::{debug, info};
use mysql::{Conn, Opts, OptsBuilder};
use parse_duration;
use std::{
    borrow::Cow,
    sync::{
        atomic::{AtomicBool, Ordering},
        Arc,
    },
    thread,
    time::Duration,
};

type BoxError = Box<dyn std::error::Error>;

pub struct MySQLPinger {
    opts: Arc<Opts>,
    interval: Duration,
    forever: bool,
    max_retry: u64,
    canceled: AtomicBool,
}

impl MySQLPinger {
    pub fn from_arg(m: &ArgMatches) -> Result<Self, BoxError> {
        let interval = parse_duration::parse(m.value_of("interval").unwrap())?;
        // we need OptsBuilder type first, then calling building methods
        let mut builder = OptsBuilder::default();
        builder
            .ip_or_hostname(m.value_of("host"))
            .tcp_port(
                m.value_of("port")
                    .unwrap()
                    .parse::<u16>()
                    .map_err(|e| format!("invalid port {}", e))?,
            )
            .user(m.value_of("user"))
            .pass(m.value_of("pass"))
            .prefer_socket(false)
            .db_name(m.value_of("dbname"))
            .tcp_connect_timeout(Some(interval));

        Ok(Self {
            opts: Arc::new(builder.into()),
            interval,
            forever: m.is_present("forever"),
            max_retry: m.value_of("max_retry").unwrap().parse()?,
            canceled: AtomicBool::new(false),
        })
    }

    pub fn stop(&self) {
        debug!("stop called");
        self.canceled.store(true, Ordering::Relaxed)
    }

    pub fn ping(&self) -> Result<(), BoxError> {
        info!(
            "ping -> addr:{host}:{port} user:{user} db:{db}",
            host = self.opts.get_ip_or_hostname().unwrap_or(""),
            port = self.opts.get_tcp_port(),
            user = self.opts.get_user().unwrap_or(""),
            db = self.opts.get_db_name().unwrap_or(""),
        );
        debug!(
            "interval:{interval:.1}sec attempt:{attempt}",
            interval = self.interval.as_secs_f64(),
            attempt = self.max_attempt_symbol(),
        );

        let mut attempt = 1;
        let max_attempt = self.max_retry + 1;
        loop {
            if !self.forever && attempt > max_attempt {
                return Err("Max retry count exceeded".into());
            }
            if self.canceled.load(Ordering::Relaxed) {
                return Err("Canceled".into());
            }

            use mysql::DriverError;
            use mysql::Error::*;
            let opts = Arc::clone(&self.opts);
            match Conn::new(Opts::clone(&opts)) {
                Ok(mut conn) => {
                    if conn.ping() {
                        return Ok(());
                    }
                }
                Err(DriverError(DriverError::CouldNotConnect(err))) => {
                    if let Some(err) = err {
                        let (_, description, _) = err;
                        info!("{}/{} {}", attempt, self.max_attempt_symbol(), description);
                    }
                }
                Err(DriverError(DriverError::ConnectTimeout)) => {
                    info!(
                        "{}/{} {}",
                        attempt,
                        self.max_attempt_symbol(),
                        "Connection timeout"
                    );
                }
                Err(err) => return Err(Box::new(err)),
            }

            thread::sleep(self.interval);
            attempt = attempt.wrapping_add(1);
        }
    }

    fn max_attempt_symbol(&self) -> Cow<'static, str> {
        if self.forever {
            "♾ ".into()
        } else {
            (self.max_retry + 1).to_string().into()
        }
    }
}
```

Connectionをはるために、[mysql crate](https://github.com/blackbeam/rust-mysql-simple)を利用しました。
[issue](https://github.com/blackbeam/rust-mysql-simple/issues/173)でもあがっていたのですが

```rust

OptsBuilder::new().tcp_port().user()
```
のように、`OptsBuilder`を生成してそのまま、methodを呼ぶと、`Opts`に変換できずにハマってしまい、以下のようにしました。

```rust

        let mut builder = OptsBuilder::default();
        builder
            .ip_or_hostname(m.value_of("host"))    
            // ...
        Ok(Self {
            opts: Arc::new(builder.into()),
           // ...
        }
```


## Dockerfile

task runner系のツールに書いて、開発者のlocal環境に依存しないようにするためにdocker imageにしました。


```Dockerfile
FROM rust:1.41.0 as builder

WORKDIR /usr/src/project

COPY . .

RUN cargo install --path .

ENTRYPOINT ["mysqlpinger"]
```

この書き方だと、image sizeがかなり大きくなってしまう(1.65GB)ので、multi stageで、buildとruntimeをわけられるにしたいです。


## Go

最初はGoで書いていました。`context.Context`のおかげで、timeout系の処理が非常に書きやすいと思いました。

```go
package main

import (
	"context"
	"database/sql"
	"flag"
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/go-sql-driver/mysql"
)

func main() {
	host := flag.String("host", "localhost", "host")
	port := flag.String("port", "3306", "port")
	user := flag.String("user", "root", "user")
	pass := flag.String("pass", "root", "pass")
	name := flag.String("name", "knight_db", "database name")
	rawTimeout := flag.String("timeout", "60s", "connection wait timeout")
	checkSlave := flag.Bool("check-slave", false, "check slave status")

	flag.Parse()
	start := time.Now()

	cfg := mysql.Config{
		User:                 *user,
		Passwd:               *pass,
		Net:                  "tcp",
		Addr:                 *host + ":" + strings.TrimLeft(*port, ":"),
		DBName:               *name,
		AllowNativePasswords: true,
	}

	db, err := sql.Open("mysql", cfg.FormatDSN())
	exitIfErr(err, 1)

	timeout, err := time.ParseDuration(*rawTimeout)
	exitIfErr(err, 1)
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()

	// connectionがはれない場合、以下のエラーが出続けてしまうので静かにしてもらう
	// [mysql] 2020/01/31 12:55:47 packets.go:36: unexpected EOF
	mysql.SetLogger(&NopLogger{})
	fmt.Printf("connecting to mysql(dsn: %s)\n", cfg.FormatDSN())
	err = waitReady(ctx, db)
	if err == nil {
		fmt.Printf("successfully connected to mysql(elapsed: %s)\n", time.Since(start))
	} else {
		fmt.Fprintf(os.Stderr, "\n%s\n", err.Error())
		os.Exit(2)
	}

	if *checkSlave {
		err := checkSlaveStatus(db)
		exitIfErr(err, 3)
	}
}

func waitReady(ctx context.Context, db *sql.DB) error {
	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		default:
		}

		err := db.Ping()
		if err == nil {
			return nil
		}
		fmt.Printf(".")
		time.Sleep(time.Second)
	}
}

func checkSlaveStatus(db *sql.DB) error {
	fmt.Println("checking slave status...")
	rows, err := db.Query("SHOW SLAVE STATUS")
	if err != nil {
		return err
	}
	columns, err := rows.Columns()
	if err != nil {
		return err
	}

	values := make([]interface{}, len(columns))
	for rows.Next() {
		for i := 0; i < len(columns); i++ {
			var s sql.NullString
			values[i] = &s
		}
		err := rows.Scan(values...)
		if err != nil {
			return err
		}
	}

	ioRunning, sqlRunning := false, false
	for i, column := range columns {
		if column == "Slave_IO_Running" {
			ioRunning = values[i].(*sql.NullString).String == "Yes"
		}
		if column == "Slave_SQL_Running" {
			sqlRunning = values[i].(*sql.NullString).String == "Yes"
		}
	}

	fmt.Printf("Slave_IO_Running: %v SLave_SQL_Running: %v\n", ioRunning, sqlRunning)

	if !ioRunning || !sqlRunning {
		return fmt.Errorf("slave thread does not work :(")
	}
	return nil
}

func exitIfErr(err error, code int) {
	if err != nil {
		fmt.Fprintln(os.Stderr, err.Error())
		os.Exit(code)
	}
}

type NopLogger struct{}

func (l *NopLogger) Print(_ ...interface{}) {}
```