# Sessions Implementation

> **Event-Sourced Session Management with Plugin Extension Points**  
> **Design Source**: [Container Design](../design/container.phase.1.md), [Class Design](../design/classes.phase.1.md)  
> **Implementation**: Python 3.12+ with Event Sourcing and Functional Patterns  
> **Purpose**: Immutable session management with plugin-extensible event handling

## Overview

This document implements the event-sourced session management system that provides immutable session state with plugin-extensible event handlers. The implementation follows functional programming principles with event sourcing patterns and plugin extension points.

## Event-Sourced Session Architecture

### Core Session Implementation

```python
from typing import Dict, List, Optional, Any, Tuple, Callable
from dataclasses import dataclass, field
from abc import ABC, abstractmethod
import asyncio
from datetime import datetime
from enum import Enum
import uuid
from models import SessionId, EventId, PluginId, SessionEvent, SessionState

@dataclass(frozen=True)
class EventSourcedSession:
    """
    Immutable event-sourced session with plugin-extensible event handling.
    
    Session state is reconstructed from immutable event streams with functional projections.
    """
    session_id: SessionId
    events: Tuple[SessionEvent, ...] = field(default_factory=tuple)
    current_state: SessionState = field(default_factory=lambda: SessionState(session_id=""))
    event_handlers: Dict[str, Tuple[Any, ...]] = field(default_factory=dict)  # EventHandler chains
    metadata: Dict[str, Any] = field(default_factory=dict)
    
    def append_event(self, event: SessionEvent) -> 'EventSourcedSession':
        """
        Append event to session immutably.
        
        Args:
            event: Event to append
            
        Returns:
            New session with event appended
        """
        new_events = self.events + (event,)
        return EventSourcedSession(
            session_id=self.session_id,
            events=new_events,
            current_state=self.current_state,
            event_handlers=self.event_handlers,
            metadata=self.metadata
        )
    
    def add_event_handler(self, event_type: str, handler: 'EventHandler') -> 'EventSourcedSession':
        """
        Add event handler for specific event type immutably.
        
        Args:
            event_type: Type of events to handle
            handler: Event handler to add
            
        Returns:
            New session with handler added
        """
        current_handlers = self.event_handlers.get(event_type, tuple())
        new_handlers = current_handlers + (handler,)
        
        return EventSourcedSession(
            session_id=self.session_id,
            events=self.events,
            current_state=self.current_state,
            event_handlers={**self.event_handlers, event_type: new_handlers},
            metadata=self.metadata
        )
```

### Event Handler Interface

```python
class EventHandler(ABC):
    """
    Abstract base class for session event handlers.
    
    Event handlers process session events and can generate new events or modify event data.
    """
    
    @property
    @abstractmethod
    def handler_name(self) -> str:
        """Handler identifier."""
        pass
    
    @property
    @abstractmethod
    def handled_event_types(self) -> List[str]:
        """List of event types this handler processes."""
        pass
    
    @abstractmethod
    async def handle_event(self, event: SessionEvent, session: EventSourcedSession) -> Optional[SessionEvent]:
        """
        Handle session event and optionally return new event.
        
        Args:
            event: Event to handle
            session: Current session state
            
        Returns:
            Optional new event or None
        """
        pass
```

### Session Manager

```python
class SessionManager:
    """
    High-level session management with event sourcing and plugin integration.
    
    Manages session lifecycle, event processing, and state reconstruction.
    """
    
    def __init__(self):
        self.sessions: Dict[SessionId, EventSourcedSession] = {}
    
    async def create_session(self, session_id: Optional[SessionId] = None) -> SessionId:
        """
        Create new session with initial state.
        
        Args:
            session_id: Optional session ID, generated if not provided
            
        Returns:
            Session ID
        """
        sid = session_id or str(uuid.uuid4())
        
        # Create initial session
        initial_state = SessionState(session_id=sid)
        session = EventSourcedSession(session_id=sid, current_state=initial_state)
        
        # Store session
        self.sessions[sid] = session
        
        return sid
    
    async def record_interaction(self, session_id: SessionId, query: str, response: str) -> bool:
        """Record user interaction in session."""
        event = SessionEvent(
            session_id=session_id,
            payload={
                "query": query,
                "response": response,
                "timestamp": datetime.utcnow().isoformat()
            }
        )
        
        session = self.sessions.get(session_id)
        if session:
            self.sessions[session_id] = session.append_event(event)
            return True
        return False
```

## Integration with Plugin System

The session system integrates with the plugin system through:

1. **EventHandler as Plugin**: Event handlers implement the plugin interface
2. **Handler Registration**: Plugins can register event handlers for specific event types
3. **Event Enhancement**: Handlers can add plugin-specific metadata to events
4. **State Extension**: Plugin state can be stored in session metadata

## Usage Example

```python
# Initialize session manager
session_manager = SessionManager()

# Create session
session_id = await session_manager.create_session()

# Record user interaction
await session_manager.record_interaction(
    session_id,
    query="Analyze main.py for errors",
    response="Found 3 potential issues in main.py"
)
```

## Future Phase Extensions

This session system provides extension points for future phases:

- **Phase 2 RAG**: Event handlers for semantic context storage and retrieval
- **Phase 3 sAgents**: Event handlers for agent coordination and communication  
- **Phase 4 Autonomy**: Event handlers for goal tracking and self-improvement metrics 