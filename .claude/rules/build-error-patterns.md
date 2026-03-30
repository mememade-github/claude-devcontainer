# Build Error Patterns Reference

> Reference for build-error-resolver agent. Common error patterns and fixes.

## Common Error Patterns & Fixes

**Pattern 1: Type Inference Failure**
```typescript
// ERROR: Parameter 'x' implicitly has an 'any' type
function add(x, y) { return x + y }
// FIX: Add type annotations
function add(x: number, y: number): number { return x + y }
```

**Pattern 2: Null/Undefined Errors**
```typescript
// ERROR: Object is possibly 'undefined'
const name = user.name.toUpperCase()
// FIX: Optional chaining
const name = user?.name?.toUpperCase()
```

**Pattern 3: Missing Properties**
```typescript
// ERROR: Property 'age' does not exist on type 'User'
// FIX: Add property to interface
interface User { name: string; age?: number }
```

**Pattern 4: Import Errors**
```typescript
// ERROR: Cannot find module '@/lib/utils'
// FIX 1: Check tsconfig paths
// FIX 2: Use relative import
// FIX 3: Install missing package
```

**Pattern 5: Type Mismatch**
```typescript
// ERROR: Type 'string' is not assignable to type 'number'
const age: number = "30"
// FIX: parseInt("30", 10) or change type
```

**Pattern 6: Generic Constraints**
```typescript
// ERROR: Type 'T' is not assignable to type 'string'
function getLength<T>(item: T): number { return item.length }
// FIX: Add constraint
function getLength<T extends { length: number }>(item: T): number { return item.length }
```

**Pattern 7: React Hook Errors**
```typescript
// ERROR: React Hook "useState" cannot be called conditionally
// FIX: Move hooks to top level of component
```

**Pattern 8: Async/Await Errors**
```typescript
// ERROR: 'await' only allowed in async functions
// FIX: Add async keyword to function
```

**Pattern 9: Module Not Found**
```typescript
// ERROR: Cannot find module 'react'
// FIX: npm install react && npm install -D @types/react
```

**Pattern 10: Next.js Specific**
```typescript
// ERROR: Fast Refresh full reload
// FIX: Separate component exports from constant exports into different files
```
