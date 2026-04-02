# KWB Shipper Portal — Real-Time Tracking Map Specification

**Agent:** Agent 5  
**Date:** April 2, 2026  
**Focus:** Real-time load tracking visualization + status timeline

---

## Overview

The Tracking Map provides shippers with real-time visibility into their loads:
- **Live map:** Origin → Destination → Current Driver Location
- **Status timeline:** posted → assigned → dispatched → in_transit → delivered
- **ETA countdown:** Real-time delivery estimate with progress
- **Driver info:** Driver name + phone (if permissions allow)
- **Stop details:** Pickup/delivery actual vs. estimated times

---

## Technical Architecture

### Frontend Stack
- **Map Library:** Google Maps JavaScript API (maps-react)
- **Real-Time Updates:** Salesforce Platform Events (via Pub/Sub API)
- **Refresh Interval:** 30 seconds (configurable)
- **Data Source:** Load__c + Check_In__c + POD__c objects

### Component Structure
```
TrackingDashboard.jsx
├── LoadSelector (dropdown: select load to track)
├── TrackingMap (React component with Google Maps)
│   ├── Origin marker (shipper location)
│   ├── Destination marker (receiver location)
│   ├── Driver location marker (real-time GPS)
│   ├── Route polyline (driving route)
│   └── Info windows (on click)
├── StatusTimeline (visual progress: posted → delivered)
└── LoadDetails panel
    ├── Driver info (name, phone, vehicle)
    ├── Estimated vs. Actual times
    ├── ETA countdown timer
    └── Current status badge
```

### Real-Time Data Flow

```
┌────────────────────────────────────┐
│ Salesforce Platform Events         │
│ (Published by Driver App)          │
├────────────────────────────────────┤
│                                    │
│ Event: Load_Assignment_Event__e    │
│ Event: Check_In_Event__e           │
│ Event: POD_Complete_Event__e       │
│                                    │
└────────────┬───────────────────────┘
             ↓
┌────────────────────────────────────┐
│ Salesforce Pub/Sub API             │
│ (Streaming subscription)           │
└────────────┬───────────────────────┘
             ↓
┌────────────────────────────────────┐
│ React Component                    │
│ (useSalesforceSubscription hook)   │
│ • Fetch new events                 │
│ • Update component state           │
│ • Refresh map + ETA                │
└────────────┬───────────────────────┘
             ↓
┌────────────────────────────────────┐
│ Google Maps Layer                  │
│ • Add/move markers                 │
│ • Update polyline                  │
│ • Show updated info windows        │
└────────────────────────────────────┘
```

---

## Map Component Implementation

### Load Selector

```jsx
// Component: TrackingDashboard.jsx

export function TrackingDashboard({ shipperId }) {
  const [selectedLoadId, setSelectedLoadId] = useState(null);
  const [loads, setLoads] = useState([]);

  useEffect(() => {
    // Fetch all loads for this shipper
    fetchShipperLoads(shipperId).then(setLoads);
  }, [shipperId]);

  const selectedLoad = loads.find(l => l.id === selectedLoadId);

  return (
    <div className="tracking-container">
      {/* Load Dropdown */}
      <select 
        value={selectedLoadId || ''} 
        onChange={(e) => setSelectedLoadId(e.target.value)}
        className="load-selector"
      >
        <option value="">Select a load to track...</option>
        {loads.map(load => (
          <option key={load.id} value={load.id}>
            Load #{load.name} - {load.shipper} → {load.receiver}
            ({load.status})
          </option>
        ))}
      </select>

      {selectedLoad && (
        <>
          <TrackingMap load={selectedLoad} />
          <StatusTimeline load={selectedLoad} />
          <LoadDetailsPanel load={selectedLoad} />
        </>
      )}
    </div>
  );
}
```

### Google Maps Component

```jsx
// Component: TrackingMap.jsx

import { GoogleMap, Marker, Polyline, InfoWindow } from '@react-google-maps/api';

export function TrackingMap({ load }) {
  const [driverLocation, setDriverLocation] = useState(null);
  const [showInfoWindow, setShowInfoWindow] = useState(null);
  const [route, setRoute] = useState([]);

  useEffect(() => {
    // Subscribe to real-time driver location updates
    const unsubscribe = subscribeToDriverLocation(load.id, (location) => {
      setDriverLocation(location);
    });

    return unsubscribe;
  }, [load.id]);

  useEffect(() => {
    // Calculate route from origin → destination
    calculateRoute(
      {
        lat: load.pickupLatitude,
        lng: load.pickupLongitude
      },
      {
        lat: load.deliveryLatitude,
        lng: load.deliveryLongitude
      }
    ).then(setRoute);
  }, [load]);

  const mapCenter = driverLocation || {
    lat: load.pickupLatitude,
    lng: load.pickupLongitude
  };

  return (
    <div className="tracking-map-container">
      <GoogleMap
        mapContainerStyle={{ width: '100%', height: '500px' }}
        center={mapCenter}
        zoom={8}
        options={{
          fullscreenControl: true,
          mapTypeControl: true,
          streetViewControl: true,
          zoomControl: true
        }}
      >
        {/* Origin Marker (Shipper) */}
        <Marker
          position={{
            lat: load.pickupLatitude,
            lng: load.pickupLongitude
          }}
          icon="http://maps.google.com/mapfiles/ms/icons/green-dot.png"
          onClick={() => setShowInfoWindow('origin')}
          title={`Pickup: ${load.shipper}`}
        />
        {showInfoWindow === 'origin' && (
          <InfoWindow
            position={{
              lat: load.pickupLatitude,
              lng: load.pickupLongitude
            }}
            onCloseClick={() => setShowInfoWindow(null)}
          >
            <div>
              <h4>{load.shipper}</h4>
              <p>{load.pickupAddress}</p>
              <p>Window: {load.pickupTimeWindow}</p>
            </div>
          </InfoWindow>
        )}

        {/* Destination Marker (Receiver) */}
        <Marker
          position={{
            lat: load.deliveryLatitude,
            lng: load.deliveryLongitude
          }}
          icon="http://maps.google.com/mapfiles/ms/icons/red-dot.png"
          onClick={() => setShowInfoWindow('destination')}
          title={`Delivery: ${load.receiver}`}
        />
        {showInfoWindow === 'destination' && (
          <InfoWindow
            position={{
              lat: load.deliveryLatitude,
              lng: load.deliveryLongitude
            }}
            onCloseClick={() => setShowInfoWindow(null)}
          >
            <div>
              <h4>{load.receiver}</h4>
              <p>{load.deliveryAddress}</p>
              <p>Window: {load.deliveryTimeWindow}</p>
            </div>
          </InfoWindow>
        )}

        {/* Driver Location Marker (Real-Time) */}
        {driverLocation && (
          <>
            <Marker
              position={driverLocation}
              icon="http://maps.google.com/mapfiles/ms/icons/blue-dot.png"
              onClick={() => setShowInfoWindow('driver')}
              title={`Driver: ${load.driverName}`}
            />
            {showInfoWindow === 'driver' && (
              <InfoWindow
                position={driverLocation}
                onCloseClick={() => setShowInfoWindow(null)}
              >
                <div>
                  <h4>{load.driverName}</h4>
                  <p>Vehicle: {load.vehicleNumber}</p>
                  <p>Phone: <a href={`tel:${load.driverPhone}`}>{load.driverPhone}</a></p>
                  <p>Last update: {formatTime(driverLocation.timestamp)}</p>
                </div>
              </InfoWindow>
            )}
          </>
        )}

        {/* Route Polyline */}
        {route.length > 0 && (
          <Polyline
            path={route}
            options={{
              strokeColor: '#4a9eff',
              strokeOpacity: 0.7,
              strokeWeight: 3,
              geodesic: true
            }}
          />
        )}
      </GoogleMap>
    </div>
  );
}

// Helper: Subscribe to driver location
function subscribeToDriverLocation(loadId, callback) {
  // Subscribe to Salesforce platform events
  const query = `SELECT Id, Latitude__c, Longitude__c, Event_DateTime__c 
                 FROM Check_In__c 
                 WHERE Load__c = '${loadId}' 
                 ORDER BY Event_DateTime__c DESC 
                 LIMIT 1`;

  // Set up 30-second polling (or use Pub/Sub API)
  const intervalId = setInterval(async () => {
    const result = await soqlQuery(query);
    if (result.records.length > 0) {
      const location = {
        lat: result.records[0].Latitude__c,
        lng: result.records[0].Longitude__c,
        timestamp: result.records[0].Event_DateTime__c
      };
      callback(location);
    }
  }, 30000);

  return () => clearInterval(intervalId);
}

// Helper: Calculate route using Google Maps Directions API
async function calculateRoute(origin, destination) {
  const directionsService = new google.maps.DirectionsService();
  const result = await directionsService.route({
    origin,
    destination,
    travelMode: google.maps.TravelMode.DRIVING
  });

  return result.routes[0].overview_path.map(point => ({
    lat: point.lat(),
    lng: point.lng()
  }));
}
```

### Status Timeline Component

```jsx
// Component: StatusTimeline.jsx

export function StatusTimeline({ load }) {
  const statuses = [
    { key: 'POSTED', label: 'Load Posted', completed: true },
    { key: 'ASSIGNED', label: 'Assigned to Driver', completed: load.status !== 'POSTED' },
    { key: 'IN_PICKUP', label: 'Arrived at Pickup', completed: load.checkInPickupAt },
    { key: 'IN_TRANSIT', label: 'In Transit', completed: load.status === 'IN_TRANSIT' || load.status === 'AT_DELIVERY' || load.status === 'DELIVERED' },
    { key: 'AT_DELIVERY', label: 'Arrived at Delivery', completed: load.checkInDeliveryAt },
    { key: 'DELIVERED', label: 'Delivered', completed: load.status === 'DELIVERED' },
  ];

  return (
    <div className="status-timeline">
      <h3>Load Progress</h3>
      <div className="timeline">
        {statuses.map((status, index) => (
          <div key={status.key} className={`timeline-item ${status.completed ? 'completed' : 'pending'}`}>
            <div className="timeline-marker">
              {status.completed ? '✓' : '○'}
            </div>
            <div className="timeline-label">
              <p className="status-name">{status.label}</p>
              {status.completed && index > 1 && (
                <p className="status-time">
                  {formatDateTime(load[`${status.key}_at`])}
                </p>
              )}
            </div>
            {index < statuses.length - 1 && <div className="timeline-connector"></div>}
          </div>
        ))}
      </div>
    </div>
  );
}

/*
CSS for Timeline:
.status-timeline {
  padding: 20px;
  background: #f9f9f9;
  border-radius: 8px;
}

.timeline {
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.timeline-item {
  display: flex;
  gap: 15px;
  position: relative;
}

.timeline-marker {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: bold;
  color: white;
  flex-shrink: 0;
}

.timeline-item.completed .timeline-marker {
  background: #28a745;
}

.timeline-item.pending .timeline-marker {
  background: #ccc;
}

.timeline-connector {
  position: absolute;
  left: 15px;
  top: 32px;
  width: 2px;
  height: 20px;
  background: #e0e0e0;
}

.timeline-item.completed .timeline-connector {
  background: #28a745;
}

.timeline-label {
  display: flex;
  flex-direction: column;
  gap: 5px;
}

.status-name {
  font-weight: 600;
  margin: 0;
}

.status-time {
  font-size: 0.85em;
  color: #666;
  margin: 0;
}
*/
```

### ETA Countdown Component

```jsx
// Component: ETACountdown.jsx

export function ETACountdown({ load }) {
  const [timeRemaining, setTimeRemaining] = useState(null);
  const [onTimeStatus, setOnTimeStatus] = useState('ON_TIME');

  useEffect(() => {
    const updateCountdown = () => {
      const now = new Date();
      const eta = new Date(load.estimatedDeliveryDateTime);
      const diff = eta - now;

      if (diff <= 0) {
        setTimeRemaining('Delivered');
        setOnTimeStatus('DELIVERED');
      } else {
        const hours = Math.floor(diff / (1000 * 60 * 60));
        const minutes = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60));
        setTimeRemaining(`${hours}h ${minutes}m`);

        // Check if on time
        if (diff < 0) {
          setOnTimeStatus('LATE');
        } else if (hours < 1) {
          setOnTimeStatus('ARRIVING_SOON');
        } else {
          setOnTimeStatus('ON_TIME');
        }
      }
    };

    updateCountdown();
    const interval = setInterval(updateCountdown, 60000); // Update every minute

    return () => clearInterval(interval);
  }, [load]);

  const statusStyles = {
    ON_TIME: { background: '#28a745', text: 'On Time' },
    ARRIVING_SOON: { background: '#ffc107', text: 'Arriving Soon' },
    LATE: { background: '#dc3545', text: 'Late' },
    DELIVERED: { background: '#17a2b8', text: 'Delivered' }
  };

  const style = statusStyles[onTimeStatus];

  return (
    <div className="eta-countdown">
      <div className={`eta-badge`} style={{ background: style.background }}>
        <p className="eta-label">Estimated Delivery</p>
        <p className="eta-time">{timeRemaining}</p>
        <p className="eta-status">{style.text}</p>
      </div>

      <div className="eta-details">
        <div className="eta-row">
          <span>Estimated:</span>
          <strong>{formatDateTime(load.estimatedDeliveryDateTime)}</strong>
        </div>
        <div className="eta-row">
          <span>Actual (if delivered):</span>
          <strong>{load.actualDeliveryDateTime ? formatDateTime(load.actualDeliveryDateTime) : '—'}</strong>
        </div>
      </div>
    </div>
  );
}

/*
CSS:
.eta-countdown {
  padding: 20px;
  background: #f9f9f9;
  border-radius: 8px;
  display: flex;
  gap: 20px;
  align-items: center;
}

.eta-badge {
  padding: 20px;
  border-radius: 8px;
  color: white;
  text-align: center;
  flex-shrink: 0;
}

.eta-label {
  margin: 0;
  font-size: 0.9em;
  opacity: 0.9;
}

.eta-time {
  margin: 10px 0 0 0;
  font-size: 2em;
  font-weight: bold;
}

.eta-status {
  margin: 5px 0 0 0;
  font-size: 0.85em;
}

.eta-details {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.eta-row {
  display: flex;
  justify-content: space-between;
}
*/
```

### Load Details Panel

```jsx
// Component: LoadDetailsPanel.jsx

export function LoadDetailsPanel({ load }) {
  return (
    <div className="load-details-panel">
      <div className="section">
        <h4>Pickup</h4>
        <p><strong>{load.shipper}</strong></p>
        <p>{load.pickupAddress}</p>
        <p>Window: {formatTime(load.pickupDateTime)} - {formatTime(load.pickupDateTimeEnd)}</p>
        {load.checkInPickupAt && (
          <p className="actual-time">✓ Checked in: {formatDateTime(load.checkInPickupAt)}</p>
        )}
      </div>

      <div className="section">
        <h4>Delivery</h4>
        <p><strong>{load.receiver}</strong></p>
        <p>{load.deliveryAddress}</p>
        <p>Window: {formatTime(load.deliveryDateTime)} - {formatTime(load.deliveryDateTimeEnd)}</p>
        {load.checkInDeliveryAt && (
          <p className="actual-time">✓ Checked in: {formatDateTime(load.checkInDeliveryAt)}</p>
        )}
        {load.podAt && (
          <p className="actual-time">✓ POD captured: {formatDateTime(load.podAt)}</p>
        )}
      </div>

      <div className="section">
        <h4>Driver Information</h4>
        <p><strong>{load.driverName}</strong></p>
        <p>Vehicle: {load.vehicleNumber}</p>
        <p><a href={`tel:${load.driverPhone}`}>{load.driverPhone}</a></p>
      </div>

      <div className="section">
        <h4>Cargo Details</h4>
        <p>Commodity: {load.commodity}</p>
        <p>Weight: {load.weight.toLocaleString()} lbs</p>
        <p>Equipment: {load.equipmentType}</p>
      </div>
    </div>
  );
}
```

---

## Salesforce Integration

### Platform Events Setup

```apex
// Platform Event: Load_Assignment_Event__e
// Published when driver app checks in

trigger CheckInTrigger on Check_In__c (after insert) {
  List<Load_Assignment_Event__e> events = new List<Load_Assignment_Event__e>();

  for (Check_In__c checkIn : Trigger.new) {
    events.add(new Load_Assignment_Event__e(
      Load__c = checkIn.Load__c,
      Event_Type__c = checkIn.Event_Type__c,
      Event_DateTime__c = checkIn.Event_DateTime__c,
      Latitude__c = checkIn.Latitude__c,
      Longitude__c = checkIn.Longitude__c
    ));
  }

  publish_database.publishImmediate(events);
}
```

### Pub/Sub API Integration

```javascript
// React hook for subscribing to events

export function useSalesforceSubscription(query, callback) {
  useEffect(() => {
    const client = new SalesforceClient(accessToken);
    
    client.subscribe(`/event/Load_Assignment_Event__e`, (event) => {
      callback(event);
    });
  }, [accessToken]);
}
```

---

## Performance & Caching

### Data Caching Strategy
- **Load list:** Cache for 5 minutes
- **Driver location:** Real-time (update every 30 sec)
- **Route:** Cache until load status changes
- **ETA:** Recalculate every 60 seconds

### Optimization
- Lazy load Google Maps (only on tracking page)
- Debounce location updates (max 1 update per 10 seconds)
- Use web workers for route calculations
- Compress location data (store only lat/lng, not full address)

---

## Testing Checklist

- [ ] Map displays correctly (origin, destination, route)
- [ ] Driver marker updates in real-time
- [ ] Timeline progresses as load status changes
- [ ] ETA countdown updates correctly
- [ ] Click markers show info windows
- [ ] Mobile responsive (map scales on small screens)
- [ ] Accessibility: map keyboard navigable
- [ ] Performance: map loads < 3 seconds
- [ ] Offline fallback: show last-known location

---

## Success Criteria

✅ Map displays correctly (origin, destination, route)  
✅ Driver location updates every 30 seconds  
✅ Timeline shows progression visually  
✅ ETA countdown updates every minute  
✅ Mobile responsive (375px to 1920px)  
✅ WCAG AA accessibility  
✅ Loads within 3 seconds  
✅ Works with real Salesforce data  
