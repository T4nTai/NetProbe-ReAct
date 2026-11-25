# Network Design Baseline — Lab Đề tài B2 (`b2-net-rca`)

Tài liệu này mô tả thiết kế mạng chuẩn (Ground-Truth Baseline) cho lab **Containerlab + FRRouting**. Các thông số chuẩn dưới đây cũng được đưa vào **System Prompt** của Agent (`A2`) và các baseline LLM để nhận diện sai lệch cấu hình (OSPF cost/MTU/timer, BGP neighbor, ACL).

---

## 1. Kiến trúc Topology (11 node)

- **6 Router FRRouting**: `r1`, `r2`, `r3`, `r4`, `r5` (thuộc **AS 65001**, OSPF Area 0) và `isp` (thuộc **AS 65100**, kết nối eBGP với `r1`).
- **1 Switch Linux Bridge**: `sw1` (container Linux chạy bridge `br0` ghép 3 cổng `eth1–eth3`).
- **4 Host**: `h1` (sau `r2`), `h2` (sau `r4`), `h3` (sau `r5`), `h4` (sau `isp`).

```text
                        [h1: 10.1.2.10/24]
                                |
                              (eth2)
                              [r2]
                             (eth1)
                                |
                            (sw1:eth2)
[r3]--(eth1)---(sw1:eth3)---[ sw1 (br0) ]---(sw1:eth1)---(eth1)--[r1]--(eth4)---(eth1)--[isp]--(eth2)--[h4: 203.0.113.10/24]
  (10.0.123.0/24 - single path segment)                         /    \     (172.16.0.0/30 eBGP)
                                                          (eth2)      (eth3)
                                                         10.0.14.0/30  10.0.15.0/30
                                                           /            \
                                                      (eth1)            (eth1)
                                                       [r4]---(eth2)-(eth2)---[r5]
                                                      (eth3)    10.0.45.0/30   (eth3)
                                                        |                        |
                                              [h2: 10.1.4.10/24]       [h3: 10.1.5.10/24]
```

### Ý nghĩa thiết kế 2 vùng (theo Proposal)
1. **Vùng segment `sw1` (`r1, r2, r3`) — chỉ có 1 đường**:
   - Dùng để tái hiện **lỗi phía xa (`link_down_remote`)**: khi cổng `sw1:eth2` (nối `r2`) bị down, interface `r1:eth1` và `r3:eth1` vẫn `UP`, nhưng cả `r1` và `r3` đều mất OSPF neighbor với `r2` và phát sinh nhiều log `ospfd` nhất dù nguyên nhân gốc nằm tại `sw1`.
2. **Vùng tam giác `r1–r4–r5` — có đường dự phòng**:
   - Mọi cặp host (`h1–h2`, `h1–h3`, `h2–h3`) đều đi trực tiếp qua đúng 1 cạnh chính của tam giác (`cost = 10` so với đường vòng `cost = 20`).
   - Khi gieo `ospf_cost_misconfig`, `ospf_mtu_mismatch`, `ospf_timer_mismatch`, hoặc `acl_block_traffic` trên bất kỳ cạnh nào, triệu chứng lộ rõ qua `ping`/`traceroute` mà không nhất thiết phát sinh log.

---

## 2. Quy hoạch IP (IP Plan) & Interface Mapping

### 2.1 Loopback & Router ID
| Thiết bị | Role | AS | Loopback (`lo`) / Router-ID |
| :--- | :--- | :---: | :--- |
| `r1` | Core & eBGP Border | 65001 | `10.255.0.1/32` |
| `r2` | Access Router (`sw1` seg) | 65001 | `10.255.0.2/32` |
| `r3` | Peer Router (`sw1` seg) | 65001 | `10.255.0.3/32` |
| `r4` | Triangle Router | 65001 | `10.255.0.4/32` |
| `r5` | Triangle Router | 65001 | `10.255.0.5/32` |
| `isp` | External ISP Router | 65100 | `198.51.100.1/32` |

### 2.2 Kết nối liên thiết bị & LAN Host
| Link | Đầu A (IP) | Đầu B (IP) | Subnet | Giao thức / Ghi chú |
| :--- | :--- | :--- | :--- | :--- |
| L1 | `r1:eth1` (`10.0.123.1/24`) | `sw1:eth1` (`br0`) | `10.0.123.0/24` | OSPF Area 0 (broadcast, `r1` DR priority 100) |
| L2 | `r2:eth1` (`10.0.123.2/24`) | `sw1:eth2` (`br0`) | `10.0.123.0/24` | OSPF Area 0 (broadcast, `r2` priority 10) |
| L3 | `r3:eth1` (`10.0.123.3/24`) | `sw1:eth3` (`br0`) | `10.0.123.0/24` | OSPF Area 0 (broadcast, `r3` BDR priority 50) |
| L4 | `r1:eth2` (`10.0.14.1/30`) | `r4:eth1` (`10.0.14.2/30`) | `10.0.14.0/30` | OSPF Area 0 (point-to-point) |
| L5 | `r1:eth3` (`10.0.15.1/30`) | `r5:eth1` (`10.0.15.2/30`) | `10.0.15.0/30` | OSPF Area 0 (point-to-point) |
| L6 | `r4:eth2` (`10.0.45.1/30`) | `r5:eth2` (`10.0.45.2/30`) | `10.0.45.0/30` | OSPF Area 0 (point-to-point) |
| L7 | `r1:eth4` (`172.16.0.1/30`) | `isp:eth1` (`172.16.0.2/30`) | `172.16.0.0/30` | eBGP `AS 65001 ↔ AS 65100` |
| L8 | `r2:eth2` (`10.1.2.1/24`) | `h1:eth1` (`10.1.2.10/24`) | `10.1.2.0/24` | LAN `h1` (OSPF passive, gw `10.1.2.1`) |
| L9 | `r4:eth3` (`10.1.4.1/24`) | `h2:eth1` (`10.1.4.10/24`) | `10.1.4.0/24` | LAN `h2` (OSPF passive, gw `10.1.4.1`) |
| L10 | `r5:eth3` (`10.1.5.1/24`) | `h3:eth1` (`10.1.5.10/24`) | `10.1.5.0/24` | LAN `h3` (OSPF passive, gw `10.1.5.1`) |
| L11 | `isp:eth2` (`203.0.113.1/24`) | `h4:eth1` (`203.0.113.10/24`) | `203.0.113.0/24` | External LAN `h4` (gw `203.0.113.1`) |

---

## 3. Thông số Thiết kế Chuẩn (Invariant Baseline)

Mọi sai lệch so với bảng sau đều là dấu hiệu cấu hình sai (*misconfiguration*):

| Tham số | Giá trị thiết kế chuẩn |
| :--- | :--- |
| **Interface MTU** | `1500` bytes trên mọi interface dữ liệu (`eth1..eth4`) |
| **OSPF Area** | `0` (`0.0.0.0`) trên toàn bộ `r1–r5` |
| **OSPF Cost** | `10` trên mọi interface OSPF (`eth1..eth3`) |
| **OSPF Timers** | `hello-interval = 10s`, `dead-interval = 40s` |
| **OSPF Logging** | `log-adjacency-changes detail` bật trên `r1–r5` |
| **eBGP Peer** | `r1 (172.16.0.1, AS 65001)` ↔ `isp (172.16.0.2, AS 65100)` |
| **eBGP Timers** | `keepalive = 5s`, `holdtime = 15s` (tối ưu thời gian hội tụ khi sinh dataset) |
| **eBGP Logging** | `bgp log-neighbor-changes` bật trên `r1` và `isp` |
| **BGP Prefixes** | `r1` quảng bá `10.1.2.0/24`, `10.1.4.0/24`, `10.1.5.0/24`; `isp` quảng bá `203.0.113.0/24`, `198.51.100.1/32` |
| **OSPF ↔ BGP** | `r1` `redistribute bgp` vào OSPF (chỉ quảng bá prefix BGP khi phiên eBGP UP) |
| **ACL (`iptables`)** | Mặc định chính sách `ACCEPT`, không có rule `DROP`/`REJECT` trên các chain `INPUT`/`FORWARD`/`OUTPUT` |
| **Expected Shortest Paths** | `h1↔h2`: `r2→r1→r4`; `h1↔h3`: `r2→r1→r5`; `h2↔h3`: `r4→r5`; `h1/h2/h3↔h4`: qua `r1→isp` |
