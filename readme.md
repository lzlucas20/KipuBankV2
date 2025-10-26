# 🏦 KipuBankV2

// A production-ready, upgraded version of the KipuBank smart contract that adds multi-token support (ETH + ERC‑20), role-based access control (owner + admins), Chainlink price feeds for USD valuation, and USD normalized decimals. Designed for security and auditability using SafeERC20, checks-effects-interactions, custom errors and events, withdrawal and capacity limits, and clear administrative controls for safe operation on Sepolia :D.


**Cadena de Despliegue:** Sepolia Testnet

---

## 📋 Mejoras Implementadas

### 1. **Control de Acceso (Ownable + Admin Roles)**
- Uso de `Ownable` de OpenZeppelin para gestión de propietario
- Sistema de roles administrativos para permitir múltiples gestores
- Funciones sensibles protegidas con modificador `onlyAuthorized()`
- Solo el owner puede agregar/remover tokens y admins

**Beneficio:** Mayor flexibilidad operativa y seguridad descentralizada.

---

### 2. **Soporte Multi-Token (ETH + ERC-20)**
- **ETH Nativo:** Direccionado como `address(0)` para depósitos/retiros nativos
- **Tokens ERC-20:** USDC, DAI, BNB y cualquier otro token compatible
- Cada token tiene su propio price feed de Chainlink
- Uso de `SafeERC20` para transferencias seguras

**Beneficio:** Flexibilidad para usuarios que desean usar diferentes activos.

---

### 3. **Contabilidad Multi-Token con Mappings Anidados**
```solidity
mapping(address => UserBalance) private userBalances;
// Donde UserBalance contiene: mapping(address => uint256) balances
```
- Estructura `UserBalance` que contiene mappings de token a saldo
- Cada usuario puede tener saldos en múltiples tokens simultáneamente
- Contadores separados de depósitos/retiros por token

**Beneficio:** Rastreo granular de activos por usuario y token.

---

### 4. **Oráculos de Datos (Chainlink Price Feeds)**
- Integración con **Chainlink Data Feeds** para obtener precios en tiempo real
- Price feeds soportados en Sepolia:
  - **ETH/USD:** `0x694AA1769357215DE4FAC081bf1f309aDC325306`
  - **USDC/USD:** `0xA2F78ab2313a4CC594511A6712B86DfD1dAA8b6b`
  - **DAI/USD:** `0x14866185B1962B63C3Ea9413aBfB7590c0eEa798`
  - **BNB/USD:** `0xc77ba7dcf7fae16debd63ff76ae4d8891760830e`

**Beneficio:** Precios precisos y actualizados que determinan límites y conversiones.

---

### 5. **Conversión de Decimales y Normalización a USD**
- **Contabilidad interna:** Todo normalizado a 6 decimales (USDC standard)
- Función `_convertToUSD()`: Convierte cualquier token a USD con precisión
- Función `convertFromUSD()`: Convierte USD a cantidad de token (pública)
- Manejo automático de diferentes decimales de tokens

**Conversión internamente:**
```
Token Amount (con decimales nativos) 
  → Price Feed (8 decimales)
  → Normalizado a 6 decimales (USD)
```

**Beneficio:** Contabilidad uniforme y comparabilidad entre tokens.

---

### 6. **Eventos y Errores Personalizados**
- 10+ eventos específicos para diferentes operaciones
- 12+ custom errors con contexto detallado
- Mejor observabilidad para dApps y monitoreo

**Errores:**
```solidity
error UnauthorizedAccess()
error TokenNotSupported(address token)
error InsufficientBalance(uint256 requested, uint256 available)
error WithdrawalLimitExceeded(uint256 requested, uint256 limit)
error BankCapacityExceeded(uint256 totalUSD, uint256 capacity)
etc...
```

**Beneficio:** Debugging más fácil y experiencia de usuario mejorada.

---

### 7. **Seguridad y Patrones Avanzados**
- ✅ **Checks-Effects-Interactions:** Validación antes de modificar estado, transacciones externas al final
- ✅ **SafeERC20:** Protección contra tokens malformados
- ✅ **Call Pattern:** Uso de `call{value: amount}("")` para ETH seguro
- ✅ **Unchecked Arithmetic:** Optimización de gas en operaciones seguras
- ✅ **Variables Immutable:** Límites almacenados como immutable
- ✅ **Variables Constant:** Decimales estándar como constant

## 🔧 Guía de Despliegue en Sepolia

### **Requisitos Previos**
1. MetaMask o cartera compatible
2. Sepolia ETH (obtener en [faucet](https://sepoliafaucet.com))
3. Acceso a Remix IDE o hardhat

### **Opción 1: Usando Remix (Recomendado)**

#### Paso 1: Preparar el Contrato
1. Ve a https://remix.ethereum.org
2. Crea una nueva carpeta llamada `src`
3. Dentro, crea el archivo `KipuBankV2.sol`
4. Pega el código del contrato

#### Paso 2: Instalar Dependencias
1. En Remix, abre la pestaña "File Explorer"
2. Ve a "remappings.txt" y añade:
   ```
   @openzeppelin=https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.3
   @chainlink=https://github.com/smartcontractkit/chainlink/blob/develop
   ```

#### Paso 3: Compilar
1. Abre el "Solidity Compiler" (tercera pestaña)
2. Selecciona versión `0.8.20` o superior
3. Haz clic en "Compile KipuBankV2.sol"
4. Verifica que no haya errores

#### Paso 4: Desplegar
1. Abre "Deploy & Run Transactions" (cuarta pestaña)
2. Selecciona "Injected Provider - MetaMask" en Environment
3. Conecta tu billetera a **Sepolia**
4. En el constructor, ingresa los parámetros:

| Parámetro | Valor | Descripción |
|-----------|-------|-------------|
| `_withdrawalLimitUSD` | `10000000000` | 10,000 USD (en 6 decimales) |
| `_bankCapacityUSD` | `100000000000` | 100,000 USD (en 6 decimales) |
| `_ethPriceFeed` | `0x694AA1769357215DE4FAC081bf1f309aDC325306` | ETH/USD en Sepolia |

5. Haz clic en "Deploy" y confirma en MetaMask
6. ¡Contrato desplegado! 🎉

## ⛓️ Direcciones en Sepolia

### **Price Feeds de Chainlink**
```
ETH/USD:  0x694AA1769357215DE4FAC081bf1f309aDC325306
DAI/USD:  0x14866185B1962B63C3Ea9413aBfB7590c0eEa798
BNB/USD:  0xc77ba7dcf7fae16debd63ff76ae4d8891760830e
```

### **Tokens ERC-20**
```
DAI:  0xFF34B3d4Aee8ddCd6F9AFFFB6Fe49bD371b8a357
WETH: 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9
```

---

## 🏗️ Estructura del Código

```
KipuBankV2/
├── src/
│   └── KipuBankV2.sol
│       ├── TIPOS
│       │   ├── TokenInfo (struct)
│       │   └── UserBalance (struct)
│       ├── CONSTANTES
│       │   ├── INTERNAL_DECIMALS (6)
│       │   ├── SCALE (10^18)
│       │   └── ETH_ADDRESS (address(0))
│       ├── VARIABLES INMUTABLES
│       │   ├── WITHDRAWAL_LIMIT
│       │   └── BANK_CAPACITY_USD
│       ├── VARIABLES DE ESTADO
│       │   ├── userBalances (mappings anidados)
│       │   ├── supportedTokens
│       │   ├── depositCount
│       │   ├── withdrawalCount
│       │   ├── totalDepositedUSD
│       │   ├── ethPriceFeed
│       │   ├── activeTokens[]
│       │   └── admins
│       ├── EVENTOS (7 eventos)
│       ├── ERRORES (12 custom errors)
│       ├── MODIFICADORES (3 validadores)
│       ├── CONSTRUCTOR
│       ├── FUNCIONES ADMINISTRATIVAS
│       │   ├── addToken()
│       │   ├── removeToken()
│       │   ├── addAdmin()
│       │   └── removeAdmin()
│       ├── FUNCIONES DE DEPÓSITO
│       │   ├── depositETH()
│       │   ├── depositToken()
│       │   └── _depositToken() (privada)
│       ├── FUNCIONES DE RETIRO
│       │   └── withdraw()
│       ├── FUNCIONES DE CONSULTA (6 funciones)
│       │   ├── getBalance()
│       │   ├── getBalanceUSD()
│       │   ├── getAllBalances()
│       │   ├── getRemainingCapacity()
│       │   ├── getTokenInfo()
│       │   └── getActiveTokens()
│       ├── FUNCIONES DE CONVERSIÓN
│       │   ├── _convertToUSD() (privada)
│       │   └── convertFromUSD() (pública)
│       └── FALLBACK
│           └── receive()
├── README.md
└── .gitignore
```

---

## 🔐 Consideraciones de Seguridad

### **Validaciones Implementadas**
1. ✅ Verificación de autorización (owner/admin)
2. ✅ Validación de tokens soportados
3. ✅ Validación de montos (no cero)
4. ✅ Validación de saldos insuficientes
5. ✅ Límites de retiro por transacción
6. ✅ Capacidad máxima del banco
7. ✅ Validación de price feeds
8. ✅ Validación de decimales

### **Patrones de Seguridad**
- ✅ **Checks-Effects-Interactions:** Se valida antes, se modifica estado después, se hacen llamadas externas al final
- ✅ **SafeERC20:** Protección contra tokens no estándar
- ✅ **Unchecked Arithmetic:** Optimización segura en operaciones validadas
- ✅ **Retrancy Protection:** Estructura del código previene ataques reentrantes



## 🏗️ Estructura del Código

```
KipuBankV2/
├── src/
│   └── KipuBankV2.sol
│       ├── TIPOS
│       │   ├── TokenInfo (struct)
│       │   └── UserBalance (struct)
│       ├── CONSTANTES
│       │   ├── INTERNAL_DECIMALS (6)
│       │   ├── SCALE (10^18)
│       │   └── ETH_ADDRESS (address(0))
│       ├── VARIABLES INMUTABLES
│       │   ├── WITHDRAWAL_LIMIT
│       │   └── BANK_CAPACITY_USD
│       ├── VARIABLES DE ESTADO
│       │   ├── userBalances (mappings anidados)
│       │   ├── supportedTokens
│       │   ├── depositCount
│       │   ├── withdrawalCount
│       │   ├── totalDepositedUSD
│       │   ├── ethPriceFeed
│       │   ├── activeTokens[]
│       │   └── admins
│       ├── EVENTOS (7 eventos)
│       ├── ERRORES (12 custom errors)
│       ├── MODIFICADORES (3 validadores)
│       ├── CONSTRUCTOR
│       ├── FUNCIONES ADMINISTRATIVAS
│       │   ├── addToken()
│       │   ├── removeToken()
│       │   ├── addAdmin()
│       │   └── removeAdmin()
│       ├── FUNCIONES DE DEPÓSITO
│       │   ├── depositETH()
│       │   ├── depositToken()
│       │   └── _depositToken() (privada)
│       ├── FUNCIONES DE RETIRO
│       │   └── withdraw()
│       ├── FUNCIONES DE CONSULTA (6 funciones)
│       │   ├── getBalance()
│       │   ├── getBalanceUSD()
│       │   ├── getAllBalances()
│       │   ├── getRemainingCapacity()
│       │   ├── getTokenInfo()
│       │   └── getActiveTokens()
│       ├── FUNCIONES DE CONVERSIÓN
│       │   ├── _convertToUSD() (privada)
│       │   └── convertFromUSD() (pública)
│       └── FALLBACK
│           └── receive()
├── README.md
└── .gitignore
```

---

## 🔐 Consideraciones de Seguridad

### **Validaciones Implementadas**
1. ✅ Verificación de autorización (owner/admin)
2. ✅ Validación de tokens soportados
3. ✅ Validación de montos (no cero)
4. ✅ Validación de saldos insuficientes
5. ✅ Límites de retiro por transacción
6. ✅ Capacidad máxima del banco
7. ✅ Validación de price feeds
8. ✅ Validación de decimales

### **Patrones de Seguridad**
- ✅ **Checks-Effects-Interactions:** Se valida antes, se modifica estado después, se hacen llamadas externas al final
- ✅ **SafeERC20:** Protección contra tokens no estándar
- ✅ **Unchecked Arithmetic:** Optimización segura en operaciones validadas
- ✅ **Retrancy Protection:** Estructura del código previene ataques reentrantes

### **Limitaciones y Riesgos Conocidos**
1. **Dependencia de Chainlink:** Si Chainlink se cae, el contrato no puede procesar conversiones
2. **Manipulación de Precios:** Los precios pueden ser volátiles; considera agregar time locks
3. **Tokens Malformados:** Aunque SafeERC20 ayuda, algunos tokens exóticos podrían no funcionar
4. **Gas Límite:** Con muchos tokens activos, `getAllBalances()` podría exceder gas límite

---

## 📊 Decisiones de Diseño y Trade-offs
---
### **1. SafeERC20 vs Transfer Directo**
**Decisión:** SafeERC20 de OpenZeppelin
- ✅ Protección contra tokens malformados
- ✅ Mejor UX (no reverter silenciosamente)

**Trade-off:** mayor seguridad a costa de mayos costo de gas
---

### **2. Sistema de Admins vs Solo Owner**
**Decisión:** owner y admins
- ✅ Mayor flexibilidad operativa
- ✅ No centralización excesiva
- ❌ Mayor superficie de ataque
---

### **3. Mappings Anidados vs Array de Saldos**
**Decisión:** Mappings anidados
- ✅ Acceso O(1) a saldos
- ✅ Menor consumo de gas
- ❌ No se pueden iterar directamente

**Trade-off:** Sacrificamos iterabilidad por eficiencia de gas


---
### **4. Contabilidad en USD vs Tokens Nativos**
**Decisión:** Contabilidad interna en USD, tokens nativos externamente
- ✅ Límites uniformes para todos los tokens
- ✅ Fácil de entender para usuarios
- ❌ Dependencia de price feeds

**Trade-off:** Complejidad adicional pero mejor UX


