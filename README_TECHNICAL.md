# README Técnico - Galactis

Este documento fornece uma visão técnica detalhada do projeto Galactis, um jogo estilo Bomberman implementado em MIPS Assembly.

---

## Sumário

- [Visão Geral da Arquitetura](#visão-geral-da-arquitetura)
- [Estrutura do Projeto](#estrutura-do-projeto)
- [Sistema de Memória](#sistema-de-memória)
- [Módulos do Engine](#módulos-do-engine)
- [Fluxo de Execução](#fluxo-de-execução)
- [Sistema de Renderização](#sistema-de-renderização)
- [Sistema de Colisão](#sistema-de-colisão)
- [Sistema de Bombas](#sistema-de-bombas)
- [Sistema de Inimigos](#sistema-de-inimigos)
- [Geração de Sprites](#geração-de-sprites)
- [Convenções e Padrões](#convenções-e-padrões)
- [Referências Técnicas](#referências-técnicas)

---

## Visão Geral da Arquitetura

O Galactis utiliza a arquitetura MIPS32 e executa no simulador MARS (MIPS Assembler and Runtime Simulator) versão 4.5. O jogo faz uso extensivo de:

- **Memory-Mapped I/O (MMIO)** para entrada de teclado
- **Bitmap Display** para saída gráfica
- **Macros e pseudo-instruções** para abstração de código

### Especificações Técnicas

| Parâmetro | Valor |
|-----------|-------|
| Display físico | 512x512 pixels |
| Unidade de pixel | 4x4 pixels reais |
| Resolução efetiva | 128x128 pixels |
| Tamanho do sprite | 5x5 pixels |
| Base do Bitmap | 0x10000000 |
| Endereço MMIO teclado (ctrl) | 0xFFFF0000 |
| Endereço MMIO teclado (data) | 0xFFFF0004 |

---

## Estrutura do Projeto

```
Galactis/
├── main.asm              # Ponto de entrada e loop principal
├── engine/               # Módulos do motor do jogo
│   ├── config.asm        # Constantes, macros e configurações
│   ├── gfx.asm           # Primitivas gráficas
│   ├── hud.asm           # Interface do usuário (HUD)
│   ├── input.asm         # Sistema de entrada
│   ├── collide.asm       # Sistema de colisão
│   ├── player.asm        # Lógica e renderização do jogador
│   ├── bomb.asm          # Sistema de bombas
│   └── enemy.asm         # Sistema de inimigos (IA)
├── sprites/              # Assets gráficos
│   ├── *.asm             # Sprites compilados para assembly
│   └── *.bmp             # Imagens fonte
└── tools/                # Scripts utilitários
    ├── gen_sprites_from_bitmap.py   # Conversor de imagem para ASM
    └── generate_all.ps1             # Script de geração em lote
```

---

## Sistema de Memória

### Mapa de Memória

```
0x10000000 - 0x1000FFFF : Bitmap Display (128x128 * 4 bytes = 65536 bytes)
0x10010000 - 0x1001FFFF : Heap / Data segment (.data)
0xFFFF0000             : MMIO Keyboard Control Register
0xFFFF0004             : MMIO Keyboard Data Register
```

### Buffer de Background

O sistema utiliza um buffer de background (`bg_buffer`) de 65536 bytes para preservar o estado do mapa. Este buffer permite:

- Restaurar pixels quando sprites se movem
- Evitar "trails" (rastros) durante animações
- Preservar elementos estáticos do cenário

```assembly
bg_buffer: .space 65536  # 128 * 128 * 4 bytes
```

### Paleta de Colisão

Cores que bloqueiam movimento são armazenadas em uma paleta:

```assembly
COLLISION_PALETTE:
    .word 0x00081C63      # WALL_COLOR (azul escuro)
    .word 0x0026775E      # BREKABLE_COLOR (verde)
    .word 0x000AA978      # BREKABLE_COLOR2 (verde claro)
```

---

## Módulos do Engine

### config.asm

Define constantes globais usando diretivas `.eqv` (equivalente ao `#define` em C):

```assembly
.eqv SCREEN_W 128
.eqv SCREEN_H 128
.eqv SPR_W 5
.eqv SPR_H 5
.eqv BITMAP_BASE 0x1000   # Upper 16 bits (0x10000000)
.eqv FRAME_DELAY 50000
.eqv BOMB_TIMER_SECONDS 3
```

**Macros utilitárias:**

```assembly
.macro PUSH(%r)
  addiu $sp, $sp, -4
  sw    %r, 0($sp)
.end_macro

.macro POP(%r)
  lw    %r, 0($sp)
  addiu $sp, $sp, 4
.end_macro
```

### gfx.asm

Primitivas gráficas de baixo nível:

| Função | Parâmetros | Descrição |
|--------|------------|-----------|
| `get_pixel` | x=$a0, y=$a1 | Retorna cor do pixel em $v0 |
| `set_pixel` | x=$a0, y=$a1, color=$a2 | Define cor do pixel |
| `draw_rect_5x5` | x=$a0, y=$a1, color=$a2 | Desenha retângulo 5x5 |

**Algoritmo de endereçamento de pixel:**

```assembly
# index = (y * SCREEN_W + x) * 4
# address = BITMAP_BASE + index
li    $t0, SCREEN_W
mul   $t1, $a1, $t0        # y * SCREEN_W
addu  $t1, $t1, $a0        # + x
sll   $t1, $t1, 2          # *4 bytes per pixel
addu  $t2, $t7, $t1        # base + offset
```

### input.asm

Sistema de entrada baseado em polling MMIO:

```assembly
# Leitura bloqueante
wait_for_key:
poll_key:
    lw  $t0, KBD_CTRL       # 0xFFFF0000
    andi $t0, $t0, 1        # bit 0 = key available
    beq $t0, $zero, poll_key
    lw  $v0, KBD_DATA       # 0xFFFF0004
    jr  $ra

# Leitura não-bloqueante
read_key_nb:
    lw   $t0, KBD_CTRL
    andi $t0, $t0, 1
    beq  $t0, $zero, no_key
    lw   $v0, KBD_DATA
    jr   $ra
no_key:
    move $v0, $zero
    jr   $ra
```

### hud.asm

Sistema de interface com renderização de dígitos 3x5:

**Estrutura de dígitos:**

```assembly
digits3x5:
    # Cada dígito: 5 bytes (1 por linha), bits representam pixels
    .byte 7,5,5,5,7  # 0: 111, 101, 101, 101, 111
    .byte 2,6,2,2,7  # 1: 010, 110, 010, 010, 111
    # ...
```

**Funções do HUD:**

| Função | Descrição |
|--------|-----------|
| `draw_digit_3x5` | Renderiza um dígito 0-9 |
| `draw_number_3x5_right` | Renderiza número alinhado à direita |
| `draw_hud` | Atualiza vidas, score e tempo |
| `fill_rect` | Preenche retângulo (usado para limpar áreas) |

---

## Fluxo de Execução

### Loop Principal

```
main:
├── Inicialização
│   ├── Configurar $s0 = BITMAP_BASE
│   ├── Inicializar vidas, score, tempo
│   └── Desenhar menu
│
├── wait_for_key (aguarda início)
│
└── start_game:
    ├── Limpar tela
    ├── Desenhar mapa
    ├── capture_bg (salvar background)
    ├── draw_hidden_square (porta escondida)
    ├── init_enemies
    ├── Posicionar player
    ├── draw_hud
    │
    └── game_loop:
        ├── delay_loop (controle de FPS)
        ├── Incrementar frame_counter
        │
        ├── [A cada 60 frames]:
        │   ├── increment_time
        │   ├── update_bomb_timer
        │   └── draw_hud
        │
        ├── update_player
        ├── update_enemies
        ├── frame_delay
        └── j game_loop
```

### Estados do Jogo

```
MENU ──[tecla]──> PLAYING ──[vidas=0]──> GAME_OVER ──[tecla]──> MENU
                     │
                     └──[porta]──> VICTORY ──[tecla]──> MENU
```

---

## Sistema de Renderização

### Double Buffering Simplificado

O jogo utiliza um esquema de "dirty rectangle" com buffer de background:

1. **capture_bg**: Copia bitmap inteiro para `bg_buffer`
2. **restore_rect_5x5**: Restaura região 5x5 do buffer para a tela
3. **draw_*_sprite**: Desenha sprite sobre a tela

### Ordem de Renderização

Para evitar artefatos visuais, a ordem de desenho é crítica:

```
1. Restaurar background (posição anterior)
2. Desenhar bomba (se ativa)
3. Desenhar inimigos
4. Desenhar player (sempre por cima)
```

### Sprites do Player

O player possui 4 direções, cada uma com sprite 5x5 (25 palavras):

```assembly
front_sprite:  # Virado para baixo
    .word 0x00FFFFFF, 0x0000A5FF, 0x0000A5FF, 0x0000A5FF, 0x00FFFFFF
    .word 0x00FFFFFF, 0x00FFFF00, 0x00FFFF00, 0x00FFFF00, 0x00FFFFFF
    # ... (total 25 palavras)
```

---

## Sistema de Colisão

### Detecção Baseada em Cor

A colisão é detectada verificando as cores dos pixels na posição de destino:

```assembly
can_move_to:
    # Para cada pixel na área 5x5:
    #   1. Ler cor do pixel com get_pixel
    #   2. Comparar com COLLISION_PALETTE
    #   3. Se match, retornar 0 (bloqueado)
    # Se nenhum match, retornar 1 (livre)
```

### Tolerância de Movimento ("Snapping")

Para facilitar a navegação, o sistema tenta ajustar a posição do player:

```
Se movimento horizontal bloqueado:
    Tentar y-1, se falhar tentar y+1

Se movimento vertical bloqueado:
    Tentar x-1, se falhar tentar x+1
```

---

## Sistema de Bombas

### Ciclo de Vida da Bomba

```
INACTIVE ──[espaço]──> ACTIVE (timer=3)
                           │
                           ├── [a cada segundo] timer--
                           │   └── Atualizar cores (cinza → laranja → vermelho)
                           │
                           └── [timer=0] EXPLODE
                                   ├── Destruir blocos em cruz
                                   ├── Verificar hit no player
                                   ├── Eliminar inimigos
                                   └── Recapturar background
```

### Algoritmo de Explosão

A explosão propaga-se em cruz (4 direções), parando ao encontrar paredes:

```assembly
explode_bomb:
    # Para cada direção (LEFT, RIGHT, UP, DOWN):
    #   Para i = 0 até 2 (3 tiles):
    #       1. check_player_in_explosion
    #       2. kill_enemies_in_explosion
    #       3. destroy_5x5_tile
    #       4. Se encontrou parede, parar direção
```

### Two-Pass Destruction

O `destroy_5x5_tile` usa duas passadas:

1. **Passada 1**: Verificar se há paredes (se sim, abortar)
2. **Passada 2**: Destruir pixels não-porta

---

## Sistema de Inimigos

### Estrutura de Dados

Inimigos são armazenados em array com estrutura fixa:

```assembly
# Cada entrada: 16 bytes (4 words)
#   offset 0: x
#   offset 4: y
#   offset 8: direction (0=UP, 1=DOWN, 2=LEFT, 3=RIGHT)
#   offset 12: active (0/1)

enemies:
    .word 114, 21, DIR_LEFT,  1  # Inimigo 1
    .word 9,   121, DIR_RIGHT, 1  # Inimigo 2
    .word 50,  60, DIR_UP,    1  # Inimigo 3
```

### Inteligência Artificial

Algoritmo de movimento "roaming":

```
1. Tentar mover na direção atual
2. Se bloqueado (parede, bomba, bounds):
   a. Rotacionar direção (sentido horário)
   b. Tentar novamente
   c. Repetir até 4 vezes
3. Se todas direções bloqueadas, ficar parado
```

### Colisão Player-Inimigo

```assembly
check_player_enemy_collisions:
    # Se cooldown > 0: decrementar e retornar
    # Para cada inimigo ativo:
    #   Se player.x == enemy.x AND player.y == enemy.y:
    #       1. Definir cooldown (i-frames)
    #       2. Restaurar sprite do player
    #       3. Chamar handle_player_death
    #       4. Redesenhar player na posição de respawn
```

---

## Geração de Sprites

### Pipeline de Conversão

```
BMP/PNG → gen_sprites_from_bitmap.py → .asm (macro + .word array)
```

### Formato de Saída

```assembly
# Auto-generated from bitmap
# Size: 128x128 (16384 pixels)
.data
.align 2
menuSprite_sprite:
    .word 0x00RRGGBB, 0x00RRGGBB, ...

.text
.macro drawMenu
    la    $t1, menuSprite_sprite  # src
    move  $t2, $s0                # dst (bitmap base)
    li    $t3, 16384              # pixel count
    
    # Loop unrolled 8x para performance
    ...
.end_macro
```

### Uso

```powershell
python tools/gen_sprites_from_bitmap.py --input menu.bmp --out menuSprite.asm --macro drawMenu
```

---

## Convenções e Padrões

### Registradores

| Registrador | Uso |
|-------------|-----|
| `$s0` | Base do bitmap display (0x10000000) |
| `$a0-$a3` | Argumentos de função |
| `$v0-$v1` | Valores de retorno |
| `$t0-$t9` | Temporários (não preservados) |
| `$sp` | Stack pointer |
| `$ra` | Return address |

### Convenção de Chamada

Todas as funções seguem:

1. `PUSH($ra)` no início
2. `PUSH` de registradores modificados
3. Corpo da função
4. `POP` em ordem reversa
5. `jr $ra`

### Comentários de Função

```assembly
# nome_funcao(param1=$a0, param2=$a1, ...): descrição
# Retorna: $v0 = valor
```

---

## Referências Técnicas

### Endereçamento MMIO

Os endereços MMIO do teclado estão localizados em:
- **Controle:** `0xFFFF0000` - Bit 0 indica se há tecla disponível
- **Dados:** `0xFFFF0004` - Código ASCII da tecla pressionada

Como esses endereços são maiores que 16 bits, o assembler MARS expande automaticamente:

```assembly
# No código-fonte (usando .eqv):
.eqv KBD_DATA  0xFFFF0004
lw  $v0, KBD_DATA

# O assembler expande para:
lui $at, 0xFFFF         # $at = 0xFFFF0000
lw  $v0, 4($at)         # Load from 0xFFFF0000 + 4 = 0xFFFF0004
```

**Nota:** Esta expansão é comportamento padrão do assembler MIPS para qualquer endereço que não cabe em 16 bits, não é específico para MMIO.

### Códigos de Teclas ASCII

| Tecla | Código |
|-------|--------|
| W | 119 |
| A | 97 |
| S | 115 |
| D | 100 |
| Espaço | 32 |
| Enter | 13 |
| P | 80 |

### Layout da Interface

```
┌────────────────────────────────────────────┐
│                  MARGEM 3px                │
├────────────────────────────────────────────┤
│         LIVES: X   SCORE: XX   TIME: XX    │  15px HUD
├────────────────────────────────────────────┤
│                  MARGEM 3px                │
├──┬────────────────────────────────────┬────┤
│4 │                                    │ 4  │
│p │                                    │ p  │
│x │        ÁREA DE JOGO                │ x  │
│  │        120 x 105 pixels            │    │
│  │        24 x 21 blocos (5x5)        │    │
│  │                                    │    │
├──┴────────────────────────────────────┴────┤
│                  MARGEM 2px                │
└────────────────────────────────────────────┘
```

### Syscalls MARS

| Código | Serviço |
|--------|---------|
| 1 | Print Integer |
| 10 | Exit |
| 11 | Print Character |

Documentação completa: [asm-editor syscall docs](https://asm-editor.specy.app/documentation/mips/syscall)

---

## TODO (Melhorias Futuras)

- [ ] Colisão baseada em tiles (ao invés de framebuffer/cores)
- [ ] Mais níveis
- [ ] Power-ups
- [ ] Sons (se suportado pelo MARS)

---

## Contribuindo

Para contribuir com o projeto:

1. Entenda a arquitetura descrita neste documento
2. Siga as convenções de código existentes
3. Teste no MARS 4.5 com as configurações especificadas
4. Documente novas funções seguindo o padrão existente

---
