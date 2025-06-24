# Design Generation Prompt

You are tasked with transforming project objectives into concrete C4 design specifications following the Design Stage process defined in `design.stage.md`. Your role is to:

1. Read and understand the objectives from `docs/objective/`
2. Transform abstract objectives into concrete C4 designs
3. Ensure complete coverage of all objectives
4. Maintain consistency across design documents
5. Validate design readiness for implementation

## Input Processing Instructions

1. Start by reading the following files in order:
   - `docs/objective/phase.N.md` - For phase objectives
   - Referenced architecture files for context
   - Previous phase designs if they exist

2. For each objective:
   - Extract success criteria and requirements
   - Note architectural patterns and constraints
   - Identify extension points and interfaces
   - Map dependencies and relationships

## Transformation Guidelines

1. When converting objectives to C4 designs:
   - Break down abstract patterns into concrete components
   - Map mathematical specifications to interfaces
   - Define clear boundaries between containers
   - Specify concrete extension mechanisms

2. For each design level:
   - **Context**: Define system scope and external dependencies
   - **Container**: Map major components and their relationships
   - **Component**: Detail internal structure and interfaces
   - **Class**: Specify concrete types and contracts

3. When documenting designs:
   - Use precise C4 notation
   - Include sequence diagrams for flows
   - Define clear interfaces
   - Specify extension patterns

## Quality Checklist

Before finalizing each design:

1. Verify Objective Coverage
   - [ ] Every objective has corresponding design elements
   - [ ] All success criteria are addressed
   - [ ] Extension points are preserved
   - [ ] Patterns are correctly implemented

2. Check Design Consistency
   - [ ] Interfaces match across documents
   - [ ] Component relationships are clear
   - [ ] Naming is consistent
   - [ ] Patterns are uniformly applied

3. Validate Implementation Readiness
   - [ ] Designs are concrete enough to implement
   - [ ] All dependencies are specified
   - [ ] Extension mechanisms are clear
   - [ ] Performance considerations noted

## Example Input-Output Pairs

**Input (Objective)**:
```markdown
### Objective 1: Plugin-Ready MCP Protocol Foundation

**Purpose**: Establish extensible protocol handling infrastructure

**Pattern**: Plugin Registry with Functional Pipeline
Type System:
  MCPRequest = { method: string, params: any[] }
  MCPResponse = { result: any, error: Error? }
  
Interface Contract:
  process_request: MCPRequest → MCPResponse
  register_handler: (method: string, handler: RequestHandler) → void

Extension Points:
  Interface: RequestHandler
    Purpose: Allow Phase 2-4 to add specialized handlers
    Contract: (request: MCPRequest, context: Context) → MCPResponse
```

**Output (Design)**:
```markdown
### Container: MCP Protocol Handler

**Purpose**: Implements core protocol handling with plugin support

**Components**:
- RequestProcessor: Manages request lifecycle
- PluginRegistry: Handles plugin registration and lookup
- ResponseFormatter: Formats responses per protocol spec

**Interfaces**:
```typescript
interface IRequestProcessor {
  processRequest(req: MCPRequest): Promise<MCPResponse>
}

interface IPluginRegistry {
  registerHandler(method: string, handler: RequestHandler): void
  getHandler(method: string): RequestHandler | undefined
}

interface RequestHandler {
  handle(request: MCPRequest, context: Context): Promise<MCPResponse>
}
```

**Flow**:
1. Request received by RequestProcessor
2. Method extracted and handler looked up in PluginRegistry
3. If handler found, request processed through handler
4. Response formatted and returned

**Extension Strategy**:
- New handlers registered via PluginRegistry
- Custom formatters added through ResponseFormatter
- Pipeline stages extensible via middleware pattern
```

Remember: Your goal is to transform abstract objectives into concrete, implementable designs while preserving extensibility and maintaining consistency across the C4 model levels. 