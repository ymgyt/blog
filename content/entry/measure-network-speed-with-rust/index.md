+++
title = "⏱ Rustでネットワークの速度を測ってみる"
slug = "measure-network-speed-with-rust"
date = "2020-02-15"
draft = false
[taxonomies]
tags = ["rust"]
+++

会社の回線が遅いなと感じ、具体的な数字を測ってみたくなったので、Rustでtcpのthroughputを計測するcliを作ってみました。
[source codeはこちら](https://github.com/ymgyt/netspeed)

## Install

`cargo`と`brew`でinstallできます。

### brew
```
$ brew tap ymgyt/netspeed
$ brew install netspeed
```

### cargo

```
cargo install netspeed
```


## 測ってみる

事前にEC2上で`netspeed server run`を実行してserverを起動してあります。defaultではこのserverへの接続を試みます。


```sh
netspeed  
INFO  Connecting to "netspeed.ymgyt.io:5555"
INFO  Start downstream duration: 3 seconds
INFO  Start upstream duration: 3 seconds
Downstream: 24.00 Mbps
  Upstream: 122.67 Mbps
```

同時実行数に制限をかけているので、上限をこえて同時に実行するとエラーになります。

```
while true; do netspeed &; done
```

```
ERROR Server decline speed test. Cause: max threads exceeded(100)
```


測り方としては、tcp接続ができたら、以下のようなおれおれプロトコルでserverにやりたいことを通知して、1MBのread/writeのloopを指定の時間内まわしています。


```rust
#[repr(u8)]
#[derive(Debug, Eq, PartialEq)]
pub enum Command {
    Ping = 1,
    RequestDownstream = 2,
    RequestUpstream = 3,
    SendBuffer = 4,
    Complete = 5,
    Ready = 6,
    Decline = 7,
    Close = 100,
}

impl From<Command> for u8 {
    fn from(cmd: Command) -> Self {
        match cmd {
            Command::Ping => 1,
            Command::RequestDownstream => 2,
            Command::RequestUpstream => 3,
            Command::SendBuffer => 4,
            Command::Complete => 5,
            Command::Ready => 6,
            Command::Decline => 7,
            Command::Close => 100,
        }
    }
}

impl TryFrom<u8> for Command {
    type Error = anyhow::Error;
    fn try_from(n: u8) -> Result<Self> {
        match n {
            1 => Ok(Command::Ping),
            2 => Ok(Command::RequestDownstream),
            3 => Ok(Command::RequestUpstream),
            4 => Ok(Command::SendBuffer),
            5 => Ok(Command::Complete),
            6 => Ok(Command::Ready),
            7 => Ok(Command::Decline),
            100 => Ok(Command::Close),
            _ => Err(anyhow!("Invalid number {} for command", n)),
        }
    }
}

```
https://github.com/ymgyt/netspeed/blob/master/src/command.rs


```rust
use crate::Result;
use anyhow::anyhow;
use byteorder::{BigEndian, ReadBytesExt, WriteBytesExt};
use std::{
    convert::{From, TryFrom},
    io::{Read, Write},
    net::{Shutdown, TcpStream},
    time::{self, Duration},
};

pub struct Operator {
    conn: TcpStream,
}

impl Operator {
    pub fn new(conn: TcpStream) -> Self {
        Self { conn }
    }
    pub fn ping_write_then_read(&mut self) -> Result<()> {
        self.write_ping().and(self.read_ping())
    }

    pub fn ping_read_then_write(&mut self) -> Result<()> {
        self.read_ping().and(self.write_ping())
    }

    fn write_ping(&mut self) -> Result<()> {
        self.write(Command::Ping)
    }

    fn read_ping(&mut self) -> Result<()> {
        self.expect(Command::Ping)
    }

    pub fn request_downstream(&mut self, duration: Duration) -> Result<()> {
        self.write(Command::RequestDownstream)
            .and_then(|_| self.write_duration(duration))
            .and_then(|_| self.flush())
    }

    pub fn request_upstream(&mut self, duration: Duration) -> Result<()> {
        self.write(Command::RequestUpstream)
            .and_then(|_| self.write_duration(duration))
            .and_then(|_| self.flush())
    }

    pub fn write_loop(&mut self, timeout: Duration) -> Result<u64> {
        let start = time::Instant::now();
        let mut write_bytes = 0u64;
        let buff = [0u8; crate::BUFFER_SIZE];
        loop {
            if start.elapsed() >= timeout {
                break;
            }
            self.send_buffer(&buff)?;
            write_bytes = write_bytes.saturating_add(crate::BUFFER_SIZE as u64);
        }
        self.write(Command::Complete)?;
        Ok(write_bytes)
    }

    pub fn read_loop(&mut self) -> Result<u64> {
        let mut buff = [0u8; crate::BUFFER_SIZE];
        let mut read_bytes = 0u64;
        loop {
            match self.read()? {
                Command::SendBuffer => {
                    self.receive_buffer(&mut buff)?;
                    read_bytes = read_bytes.saturating_add(crate::BUFFER_SIZE as u64);
                }
                Command::Complete => return Ok(read_bytes),
                _ => return Err(anyhow!("Unexpected command")),
            }
        }
    }

    pub fn send_buffer(&mut self, buff: &[u8]) -> Result<()> {
        self.write(Command::SendBuffer)?;
        Write::by_ref(&mut self.conn).write_all(buff)?;
        self.flush()
    }

    pub fn receive_buffer(&mut self, buff: &mut [u8]) -> Result<()> {
        Read::by_ref(&mut self.conn)
            .read_exact(buff)
            .map_err(anyhow::Error::from)
    }

    pub fn write(&mut self, cmd: Command) -> Result<()> {
        Write::by_ref(&mut self.conn)
            .write_u8(cmd.into())
            .map_err(anyhow::Error::from)
    }

    pub fn read(&mut self) -> Result<Command> {
        Command::try_from(Read::by_ref(&mut self.conn).read_u8()?)
    }

    pub fn write_duration(&mut self, duration: Duration) -> Result<()> {
        Write::by_ref(&mut self.conn)
            .write_u64::<BigEndian>(duration.as_secs())
            .map_err(anyhow::Error::from)
    }

    pub fn read_duration(&mut self) -> Result<Duration> {
        Read::by_ref(&mut self.conn)
            .read_u64::<BigEndian>()
            .map_err(anyhow::Error::from)
            .map(Duration::from_secs)
    }

    pub fn expect(&mut self, expect: Command) -> Result<()> {
        let actual = Command::try_from(Read::by_ref(&mut self.conn).read_u8()?)?;
        if actual != expect {
            Err(anyhow!(
                "Unexpected command. expect: {:?}, actual: {:?}",
                expect,
                actual
            ))
        } else {
            Ok(())
        }
    }

    pub fn write_decline(&mut self, reason: DeclineReason, shutdown: bool) -> Result<()> {
        self.write(Command::Decline)
            .and(self.write_decline_reason(reason))
            .and(self.flush())?;

        if shutdown {
            self.conn
                .shutdown(Shutdown::Both)
                .map_err(anyhow::Error::from)
        } else {
            Ok(())
        }
    }

    fn write_decline_reason(&mut self, reason: DeclineReason) -> Result<()> {
        let v = match reason {
            DeclineReason::MaxThreadsExceed(max_threads) => {
                // reason:32bit | description: 32bit
                let mut v: u64 = 1;
                v <<= 32;
                v += max_threads as u64;
                v
            }
            DeclineReason::Unknown => 0,
        };
        Write::by_ref(&mut self.conn)
            .write_u64::<BigEndian>(v)
            .map_err(anyhow::Error::from)
    }

    pub fn read_decline_reason(&mut self) -> Result<DeclineReason> {
        let v = Read::by_ref(&mut self.conn)
            .read_u64::<BigEndian>()
            .map_err(anyhow::Error::from)?;
        let reason = v >> 32;
        let detail = v & (std::u32::MAX as u64);
        if reason == 1 {
            Ok(DeclineReason::MaxThreadsExceed(detail as u32))
        } else {
            Ok(DeclineReason::Unknown)
        }
    }

    fn flush(&mut self) -> Result<()> {
        Write::by_ref(&mut self.conn)
            .flush()
            .map_err(anyhow::Error::from)
    }
}
```


## localで試す


localで試すには以下のようにします。


terminal1
```sh
netspeed server run  
INFO  2020-02-15T13:01:56.892922+00:00 Listening on "0.0.0.0:5555" max threads: 100
INFO  2020-02-15T13:02:04.785769+00:00 Pass concurrent threads check. (0/100)
INFO  2020-02-15T13:02:04.786067+00:00 Handle incoming connection. dispatch worker 127.0.0.1:53013 actives: 1
INFO  2020-02-15T13:02:04.786480+00:00 (Worker:127.0.0.1:53013) => Handle downstream
INFO  2020-02-15T13:02:07.787380+00:00 (Worker:127.0.0.1:53013) => Successfully handle downstream
INFO  2020-02-15T13:02:07.787475+00:00 (Worker:127.0.0.1:53013) => Handle upstream
INFO  2020-02-15T13:02:10.840054+00:00 (Worker:127.0.0.1:53013) => Successfully handle upstream
```

terminal2

```sh
netspeed --addr 127.0.0.1:5555
INFO  Connecting to "127.0.0.1:5555"
INFO  Start downstream duration: 3 seconds
INFO  Start upstream duration: 3 seconds
Downstream: 19.93 Gbps
  Upstream: 20.39 Gbps
```
