# BDD Scenarios - Messaging Application

## Feature: Web User Sends Message to Mobile User

### Scenario: Web user successfully sends a message to a selected mobile user
**Given** a web user is authenticated and viewing the user selection interface  
**And** there is at least one mobile user available in the system  
**When** the web user selects a mobile user from the list  
**And** the web user composes a message  
**And** the web user submits the message  
**Then** the message should be written to the backend database table  
**And** the message status should be set to "pending_sync"  
**And** the web user should see a confirmation that the message was sent  

### Scenario: Web user sends message with invalid recipient
**Given** a web user is authenticated  
**When** the web user attempts to select a non-existent mobile user  
**Then** the system should display an error message  
**And** the message should not be saved  

### Scenario: Web user sends empty message
**Given** a web user is authenticated  
**And** a mobile user is selected  
**When** the web user attempts to send an empty message  
**Then** the system should prevent message submission  
**And** display a validation error  

---

## Feature: Mobile User Receives Message

### Scenario: Mobile user receives message when online
**Given** a mobile user's device is online  
**And** a web user has sent a message to this mobile user  
**And** the message exists in the backend database with status "pending_sync"  
**When** the sync process runs  
**Then** the message should be synced to the mobile device's SQLite database  
**And** the message status should be updated to "synced" in the backend  
**And** the mobile user should receive a notification  
**And** the message should appear in the mobile user's inbox  

### Scenario: Mobile user receives message when offline
**Given** a mobile user's device is offline  
**And** a web user has sent a message to this mobile user  
**And** the message exists in the backend database  
**When** the mobile device comes online  
**And** the sync process runs  
**Then** the message should be synced to the mobile device's SQLite database  
**And** the mobile user should receive a notification  
**And** the message should appear in the mobile user's inbox  

### Scenario: Mobile user views incoming message
**Given** a mobile user has received a new message  
**And** the message is stored in the local SQLite database  
**When** the mobile user opens the messaging interface  
**Then** the message should be displayed with sender information  
**And** the message should show the timestamp  
**And** the message status should be visible  

---

## Feature: Mobile User Replies to Message

### Scenario: Mobile user replies while online
**Given** a mobile user has received a message  
**And** the mobile device is online  
**When** the mobile user opens the message  
**And** the mobile user composes a reply  
**And** the mobile user submits the reply  
**Then** the reply should be saved to the local SQLite database  
**And** the reply should be immediately synced to the backend database  
**And** the reply status should be set to "synced" in the local database  
**And** the web user should see the reply in their interface  

### Scenario: Mobile user replies while offline
**Given** a mobile user has received a message  
**And** the mobile device is offline  
**When** the mobile user opens the message  
**And** the mobile user composes a reply  
**And** the mobile user submits the reply  
**Then** the reply should be saved to the local SQLite database  
**And** the reply status should be set to "pending_sync" in the local database  
**And** the reply should not be synced immediately  

### Scenario: Mobile user's offline reply syncs when device comes online
**Given** a mobile user has sent a reply while offline  
**And** the reply is stored in the local SQLite database with status "pending_sync"  
**When** the mobile device comes online  
**And** the sync process runs  
**Then** the reply should be synced to the backend database  
**And** the reply status should be updated to "synced" in the local database  
**And** the web user should receive a notification of the new reply  

---

## Feature: Web User Receives Notification

### Scenario: Web user receives inbox notification for new message
**Given** a web user is authenticated  
**And** a mobile user has sent a reply to the web user  
**And** the reply has been synced to the backend database  
**When** the web user's interface polls for updates  
**Then** an inbox icon should appear indicating new messages  
**And** the inbox icon should show the count of unread messages  

### Scenario: Web user views new message after notification
**Given** a web user sees an inbox icon notification  
**When** the web user clicks on the inbox icon  
**Then** the messaging interface should open  
**And** the new message should be displayed  
**And** the inbox icon should update to reflect read status  

### Scenario: Web user receives multiple notifications
**Given** a web user is authenticated  
**And** multiple mobile users have sent replies  
**And** all replies have been synced to the backend database  
**When** the web user's interface polls for updates  
**Then** the inbox icon should show the total count of unread messages  
**And** clicking the inbox should show all unread messages  

---

## Feature: Synchronization Process

### Scenario: Successful bidirectional sync when mobile comes online
**Given** a mobile device has been offline  
**And** there are pending outgoing messages in the local SQLite database  
**And** there are new incoming messages in the backend database  
**When** the mobile device comes online  
**And** the sync process is triggered  
**Then** all pending outgoing messages should be synced to the backend  
**And** all new incoming messages should be synced to the local database  
**And** sync status should be updated for all messages  
**And** the sync process should complete successfully  

### Scenario: Sync handles network interruption
**Given** a sync process is in progress  
**When** the network connection is lost during sync  
**Then** the sync process should handle the interruption gracefully  
**And** partially synced messages should be marked appropriately  
**And** the sync should resume from the last successful point when connection is restored  

### Scenario: Sync conflict resolution
**Given** a message has been modified on both the mobile device and backend  
**And** both versions have different timestamps  
**When** the sync process runs  
**Then** the system should detect the conflict  
**And** apply conflict resolution strategy (e.g., last-write-wins or manual resolution)  
**And** both versions should be preserved for review if needed  

### Scenario: Sync with no pending changes
**Given** a mobile device is online  
**And** there are no pending outgoing messages in the local database  
**And** there are no new incoming messages in the backend  
**When** the sync process runs  
**Then** the sync should complete immediately  
**And** no database operations should be performed  
**And** sync status should remain unchanged  

---

## Feature: Offline-First Mobile Experience

### Scenario: Mobile user can view messages while offline
**Given** a mobile device is offline  
**And** there are messages stored in the local SQLite database  
**When** the mobile user opens the messaging interface  
**Then** all locally stored messages should be displayed  
**And** the interface should indicate offline status  
**And** the user should be able to read and compose messages  

### Scenario: Mobile user can compose messages while offline
**Given** a mobile device is offline  
**When** the mobile user composes a new message  
**And** the mobile user submits the message  
**Then** the message should be saved to the local SQLite database  
**And** the message should be marked as "pending_sync"  
**And** the user should see confirmation that the message will be sent when online  

### Scenario: Mobile app initializes with local data
**Given** a mobile app is launched  
**And** there is existing data in the local SQLite database  
**When** the app initializes  
**Then** the app should load data from the local database immediately  
**And** the user interface should display without waiting for network  
**And** background sync should be attempted if network is available  

---

## Feature: User Selection and Management

### Scenario: Web user selects mobile user from list
**Given** a web user is authenticated  
**And** there are multiple mobile users in the system  
**When** the web user views the user selection interface  
**Then** a list of available mobile users should be displayed  
**And** each user should show their online/offline status  
**And** the web user should be able to select a user to message  

### Scenario: Web user filters mobile users
**Given** a web user is viewing the user selection interface  
**And** there are many mobile users in the system  
**When** the web user applies a filter (e.g., by name, status)  
**Then** the user list should be filtered accordingly  
**And** only matching users should be displayed  

---

## Feature: Message Status Tracking

### Scenario: Message status updates through lifecycle
**Given** a web user sends a message  
**When** the message is created  
**Then** the message status should be "pending_sync"  
**When** the message is synced to mobile device  
**Then** the message status should be "synced"  
**When** the mobile user reads the message  
**Then** the message status should be "read" (if tracked)  

### Scenario: Reply status tracking
**Given** a mobile user has sent a reply  
**When** the reply is saved locally while offline  
**Then** the reply status should be "pending_sync"  
**When** the reply is synced to backend  
**Then** the reply status should be "synced"  
**When** the web user views the reply  
**Then** the reply status should be "read" (if tracked)  

---

## Feature: Error Handling

### Scenario: Database write failure on web
**Given** a web user attempts to send a message  
**When** the backend database write fails  
**Then** the system should display an error message to the web user  
**And** the message should not be saved  
**And** the user should be able to retry  

### Scenario: Sync failure on mobile
**Given** a mobile device comes online  
**And** there are pending messages to sync  
**When** the sync process fails due to backend error  
**Then** the pending messages should remain in "pending_sync" status  
**And** the sync should be retried automatically  
**And** the user should be notified of sync failure if persistent  

### Scenario: Local database corruption on mobile
**Given** a mobile device has a corrupted SQLite database  
**When** the mobile app attempts to read messages  
**Then** the system should detect the corruption  
**And** attempt to recover or reinitialize the database  
**And** trigger a full sync from backend when possible  

---

## Feature: Real-time Updates (Web)

### Scenario: Web user sees live message updates
**Given** a web user has an active session  
**And** the web interface is connected to the backend  
**When** a mobile user sends a reply that is synced to the backend  
**Then** the web user's interface should update automatically  
**And** the inbox icon should appear without page refresh  
**And** the new message should be visible in the conversation  

### Scenario: Web user interface reflects message status changes
**Given** a web user has sent a message  
**And** the message status changes in the backend  
**When** the web interface polls for updates  
**Then** the message status should be updated in the UI  
**And** the user should see the current status (e.g., delivered, read)  

---

## Feature: Notification Management

### Scenario: Mobile user receives push notification for new message
**Given** a mobile device is online  
**And** a new message is synced to the device  
**When** the message is received  
**Then** a push notification should be triggered  
**And** the notification should display sender and message preview  
**And** tapping the notification should open the message  

### Scenario: Mobile user dismisses notification
**Given** a mobile user has received a notification  
**When** the mobile user dismisses the notification  
**Then** the notification should be removed  
**And** the message should still be accessible in the app  
**And** the unread indicator should remain until the message is read  



