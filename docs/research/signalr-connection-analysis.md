# Comprehensive Analysis of Connection & Communication Mechanisms

**Target Repositories Analyzed:**
1. `/home/nguyen-thanh-hung/Documents/Code/CORE-MOBILE-APP-Reporting` (.NET 10 WebApi Backend & SignalR Bridge)
2. `/home/nguyen-thanh-hung/Documents/Code/Txp-Angular-Core` (Angular 22 + RxJS + Syncfusion Frontend)

---

## 1. Executive Summary

Both codebases participate in a multi-tier enterprise architecture spanning legacy .NET Framework 4.8 systems, modern .NET 10 microservices, and an Angular 22 frontend.

### Communication Pattern Summary

| Layer / Flow | Mechanism | Protocol / Library | Endpoint / Transport | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| **ERP Backend $\rightarrow$ .NET 10 WebApi** | Push Real-Time | SignalR Classic (`Microsoft.AspNet.SignalR.Client` v2.4.3) | `ServerSentEvents` / `WebSockets` / `LongPolling` $\rightarrow$ `https://.../signalr` | Bridging UHF RFID tag streams from legacy ERP |
| **.NET 10 WebApi $\rightarrow$ Mobile App** | Push Real-Time | ASP.NET Core SignalR (`Microsoft.AspNetCore.SignalR`) | `/hubs/tags` (`TagHub`) | Forwarding gate-scoped and user-scoped RFID tags to mobile |
| **.NET 10 WebApi $\rightarrow$ Angular Frontend** | Push Real-Time | ASP.NET Core SignalR (`@microsoft/signalr` v10.0.0) | `/hubs/reports` (`ReportHub`) | Realtime report completion & user notification toasts |
| **ERP Backend $\rightarrow$ Angular Frontend** | Push Real-Time | SignalR Classic (`signalr` v2.4.3 + jQuery) | `/signalr` (`AppHub`) | Direct RFID antenna/scanner device telemetry monitoring |
| **Angular $\rightarrow$ .NET 10 WebApi** | Pull REST | Axios (`axios` v1.18.1 via `AxiosHttpAdapter`) | `/api/...` (Wrapped in `ApiResponse<T>`) | CRUD, Auth, Reporting, Sync Rules, Data Grids |
| **Angular $\rightarrow$ On-Demand Polling** | Polling Stream | RxJS `timer` + `switchMap` | HTTP GET (`/api/report-runs`, `/api/central-db-sync/...`) | Short-lived status progression tracking (Job runs & bootstrap) |

---

## 2. Repository 1: `CORE-MOBILE-APP-Reporting` (.NET 10 WebApi)

### 2.1 Package Dependencies & Architecture Setup
From `WebApi/WebApi.csproj`:
```xml
<PackageReference Include="Microsoft.AspNet.SignalR.Client" Version="2.4.3" />
<PackageReference Include="Microsoft.AspNetCore.Authentication.JwtBearer" Version="10.0.7" />
<PackageReference Include="Hangfire.AspNetCore" Version="1.8.23" />
<PackageReference Include="StackExchange.Redis" Version="2.12.14" />
```

**Key Architectural Trait: Co-existence of Two Incompatible SignalR Generations**
- **Legacy SignalR Inbound (Client):** Consumes events from legacy ERP (.NET 4.8 / IIS) using `Microsoft.AspNet.SignalR.Client` 2.4.3.
- **Modern SignalR Outbound (Server):** Exposes endpoints via ASP.NET Core SignalR (`/hubs/tags` and `/hubs/reports`).

---

### 2.2 Inbound RFID Stream: `ErpHubListener`
- **File:** `WebApi/Rfid/ErpHubListener.cs`
- **Role:** Background client connecting to ERP's `AppHub`.

```csharp
// WebApi/Rfid/ErpHubListener.cs:82-119
private async Task ConnectOnceAsync(TaskCompletionSource<bool> closed, CancellationToken ct)
{
    var qs = new Dictionary<string, string>
    {
        ["sessionType"] = opt.SessionType,
        ["browser"] = opt.BrowserTag
    };

    if (!string.IsNullOrWhiteSpace(opt.AccessToken))
        qs["token"] = opt.AccessToken;

    _conn = new HubConnection(opt.HubUrl, qs);
    _proxy = _conn.CreateHubProxy(opt.HubName);

    foreach (var spec in opt.TagMethodList())
    {
        _proxy.Subscribe(spec.Method).Received += args => Dispatch(spec, args);
        log.LogInformation("Đăng ký nhận tag: {Method} routing={Routing}", spec.Method, spec.Routing);
    }

    _conn.Closed += () => closed.TrySetResult(true);
    _conn.Error += ex => log.LogWarning("SignalR ERP lỗi: {Msg}", Innermost(ex).Message);
    _conn.Reconnecting += () => log.LogWarning("SignalR ERP: đang kết nối lại");
    _conn.Reconnected += () => { _ = JoinAsync(rejoin: true); };

    var transport = CreateTransport();
    if (transport is null) await _conn.Start();
    else await _conn.Start(transport);

    await JoinAsync(rejoin: false);
}
```

- **Transport Strategy:**
  ```csharp
  // WebApi/Rfid/ErpHubListener.cs:175-181
  private IClientTransport? CreateTransport() => opt.Transport?.Trim().ToLowerInvariant() switch
  {
      "websockets" => new WebSocketTransport(),
      "serversentevents" => new ServerSentEventsTransport(),
      "longpolling" => new LongPollingTransport(),
      _ => null
  };
  ```
  Default configuration is `serverSentEvents` (`RfidRealtimeOptions.cs:40`), falling back to full autonegotiation if null.

---

### 2.3 Buffer & Dispatching: `TagForwarder`
- **File:** `WebApi/Rfid/TagForwarder.cs`
- **Pattern:** Uses `System.Threading.Channels` bounded buffer (`DropWrite` mode) to decouple fast ERP streams from potentially slow mobile WebSocket connections, preventing memory bloat.

```csharp
// WebApi/Rfid/TagForwarder.cs:26-34
private readonly Channel<(string Group, TagEnvelope Envelope)> _queue =
    Channel.CreateBounded<(string, TagEnvelope)>(
        new BoundedChannelOptions(options.Value.Forwarder.QueueCapacity)
        {
            FullMode = BoundedChannelFullMode.DropWrite,
            SingleReader = false,
            SingleWriter = false
        });
```

---

### 2.4 Outbound Hubs: `TagHub` and `ReportHub`

1. **`TagHub` (`WebApi/Hubs/Rfid/TagHub.cs`)**:
   - Route: `/hubs/tags`
   - Authorization: `[Authorize]` with claim validation (`NameIdentifier` / `sub`).
   - Group Routing:
     - `JoinGate(int gateId)` $\rightarrow$ Group `gate-{gateId}`
     - `JoinGateUser(int gateId)` $\rightarrow$ Group `gate-{gateId}-user-{userId}`
     - `JoinGarmentAutoPass()` $\rightarrow$ Group `user-{userId}`

2. **`ReportHub` (`WebApi/Hubs/Reporting/ReportHub.cs`)**:
   - Route: `/hubs/reports`
   - Groups: Auto-joins `user-{userId}` and `company-{companyId}` on connect.
   - Publisher (`WebApi/Reporting/SignalRReportRealtimePublisher.cs`): Broadcasts `ReportRunChanged`, `ScheduleRunSummaryChanged`, and `NotificationReceived`.

---

## 3. Repository 2: `Txp-Angular-Core` (Angular 22 Client)

### 3.1 Package Dependencies
From `code/package.json`:
```json
"@angular/core": "^22.0.0",
"@microsoft/signalr": "^10.0.0",
"signalr": "^2.4.3",
"jquery": "^3.7.1",
"axios": "^1.18.1",
"rxjs": "~7.8.0"
```

The frontend uses **both** `@microsoft/signalr` (ASP.NET Core SignalR) and `signalr` v2.4.3 (jQuery legacy SignalR).

---

### 3.2 SignalR Core Client: `ReportsHubSource`
- **File:** `code/src/shared/infra/realtime/reports-hub.source.ts`
- **Purpose:** Connects to `.NET 10 WebApi` at `/hubs/reports` for notifications and report runs.

```typescript
// code/src/shared/infra/realtime/reports-hub.source.ts:32-37
protected createConnection(): HubConnection {
  return new HubConnectionBuilder()
    .withUrl(this.hubUrl, { accessTokenFactory: this.buildAccessTokenFactory() })
    .withAutomaticReconnect()
    .build();
}

protected buildAccessTokenFactory(): () => Promise<string> {
  return () => this.authTokenService.getValidAccessToken();
}
```

- **Consumers:**
  - `SignalrNotificationSource` (`features/notifications/realtime/signalr-notification.source.ts`): Listens for `NotificationReceived`.
  - `ReportingRealtimeSource` (`shared/infra/realtime/reporting-realtime.source.ts`): Listens for `ReportRunChanged` and `ScheduleRunSummaryChanged`.

---

### 3.3 SignalR Legacy Client: `HubConnectionService`
- **File:** `code/src/features/rfid/monitoring/realtime/monitoring-hub.connection.ts`
- **Purpose:** Connects directly to ERP `AppHub` (`/signalr`) to monitor hardware status (Antennas, Gates, Scanners).

```typescript
// code/src/features/rfid/monitoring/realtime/monitoring-hub.connection.ts:163-201
this.connection = $.hubConnection(this.hubUrl + RFID_SIGNALR_PATH, {
  useDefaultPath: RFID_SIGNALR_USE_DEFAULT_PATH,
}) as unknown as SignalRConnection;

this.proxy = this.connection.createHubProxy(RFID_SIGNALR_HUB_NAME);
this.connection.qs = {
  [RFID_SIGNALR_TOKEN_QUERY_KEY]: token,
  [RFID_SIGNALR_SESSION_TYPE_QUERY_KEY]: RFID_SIGNALR_MONITORING_SESSION_TYPE,
};

return new Promise<void>((resolve, reject) => {
  this.connection!.start({
    jsonp: RFID_SIGNALR_JSONP_ENABLED,
    transport: RFID_SIGNALR_TRANSPORTS, // ['webSockets', 'longPolling']
  })
    .done(() => resolve())
    .fail((err: unknown) => {
      console.error('[MonitoringHub] Start failed', err);
      if (this._shouldReconnect && this._started) {
        this._scheduleReconnect();
      }
      reject(err);
    });
});
```

- **Transports Configured (`app.const.ts:44`):** `['webSockets', 'longPolling']`.
- **Streams Built on Top:**
  - `DeviceStateStream` (`device-state.stream.ts`): Listens to `receiveDeviceOnline`, `receiveStateConnected`, `receiveGreenState`, `receiveRedState`, `receiveTimeSensor`, `receiveDeviceScanConnect`.
  - `TagStream` (`tag-stream.ts`): Lazy-subscribes to `receiveDeviceReadTag` only when diagnostic popups open.

---

### 3.4 REST API & Interceptors: `AxiosHttpAdapter`
- **Files:** `code/src/shared/infra/http/axios-http.adapter.ts` and `axios-interceptor.service.ts`
- **Contract:** Standard JSON envelope `ApiResponse<T>`:
  ```json
  {
    "successed": true,
    "responseCode": 200,
    "message": "...",
    "data": { ... },
    "errors": {}
  }
  ```
- **Interceptors:**
  - Inject `Authorization: Bearer <token>`.
  - Automatically unwrap `body.data`.
  - On `responseCode: 401`, run single-flight token refresh (`AuthTokenService.refresh()`) and replay request.

---

### 3.5 Polling vs. WebSockets: Why and Where Polling is Used

1. **Short-Lived Execution Tracking (Job Progress):**
   - **File:** `code/src/features/report-schedules/utils/polling-run-status-tracker.service.ts`
   - **Implementation:**
     ```typescript
     return timer(0, 3000).pipe(
       take(20),
       switchMap(() => this.runsApi.getRuns({ reportScheduleId: scheduleId, sortOrder: 'desc', pageSize: 1 })),
       takeWhile((update) => update.status === 'running', true)
     );
     ```
   - **Reason:** When a user clicks "Run Now", maintaining persistent SignalR connection state for an ad-hoc 10-second background execution is unnecessarily complex. The bounded poll (max 20 attempts @ 3s) terminates immediately once the job finishes or fails.

2. **Bootstrap Job Progress Modal:**
   - **File:** `code/src/features/central-db-sync/components/bootstrap-jobs/bootstrap-detail-modal/bootstrap-detail-modal.component.ts`
   - **Implementation:** `timer(0, 1000)` polling `getBootstrapStatus()` until status is `'completed'` or `'failed'`.
   - **Reason:** Central DB sync jobs are managed by Hangfire queues without direct SignalR broadcaster mapping for intermediate ETL percentages.

3. **Fallback & Graceful Degradation:**
   - In `ReportsHubSource.ts:68`, if the SignalR hub is unavailable or firewalled, the application gracefully degrades because all core entities use REST seeding (`seed()` and `reconcile()`).
   - In `monitoring-hub.connection.ts`, if WebSockets fail due to network proxies/WAF, SignalR falls back to `longPolling`.

---

## 4. Architectural Relationship Diagram

```
+-------------------------------------------------------------+
|                 Legacy ERP Server (.NET 4.8)               |
|                     (AppHub at /signalr)                    |
+------------------------------+------------------------------+
                               |
              +----------------+----------------+
              | (SSE / WS / LP)                 | (WS / Long Polling)
              v                                 v
+-----------------------------+   +---------------------------+
|  .NET 10 WebApi Backend     |   |   Txp-Angular-Core App    |
|  - ErpHubListener           |   |   - HubConnectionService  |
|  - TagForwarder (Channel)   |   |     (RFID Telemetry & Map)|
|  - TagHub (/hubs/tags)      |   |   - ReportsHubSource      |
|  - ReportHub (/hubs/reports)|   |     (Notifications & Runs)|
|  - REST Controllers         |   |   - AxiosHttpAdapter      |
+--------------+--------------+   |     (REST APIs)           |
               |                  +-------------+-------------+
               | (SignalR Core)                 |
               v                                v
       Mobile UHF Client                 REST API Calls
```
