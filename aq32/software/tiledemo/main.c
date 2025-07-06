#include "common.h"
#include "esp.h"
#include "csr.h"
#include "console.h"

#define NUM_BALLS 14

// Structure to keep track of position and direction of ball sprites
struct ball {
    uint16_t x;
    uint8_t  y;
    uint16_t dx;
    uint8_t  dy;
};
struct ball balls[NUM_BALLS];

// Each ball consist of 4 8x8 sprites
static inline void setup_ball_sprites(uint8_t ball_idx) {
    uint8_t base    = ball_idx * 4;
    SPRATTR[base++] = 128 + 227;
    SPRATTR[base++] = 128 + 228;
    SPRATTR[base++] = 128 + 243;
    SPRATTR[base]   = 128 + 244;
}

// Update position of the 4 8x8 sprites take make up a ball
static inline void update_ball_sprites(uint8_t ball_idx) {
    struct ball *ballp = &balls[ball_idx];
    uint16_t     x     = ballp->x;
    uint16_t     x8    = ballp->x + 8;
    uint8_t      y     = ballp->y;
    uint8_t      y8    = ballp->y + 8;

    uint8_t base   = ball_idx * 4;
    SPRPOS[base++] = ((unsigned)y << 16) | x;
    SPRPOS[base++] = ((unsigned)y << 16) | x8;
    SPRPOS[base++] = ((unsigned)y8 << 16) | x;
    SPRPOS[base]   = ((unsigned)y8 << 16) | x8;
}

// Position Sonic character sprite on give position
static inline void sonic_sprite(uint8_t frame, int x, int y) {
    uint8_t  base   = 56;
    uint16_t spridx = 128 + 256 + (uint16_t)frame * 16;
    for (uint8_t j = 0; j < 2; j++) {
        int tx = x;
        for (uint8_t i = 0; i < 3; i++) {
            SPRATTR[base] = SPRATTR_H16 | spridx;
            SPRPOS[base]  = ((unsigned)y << 16) | tx;
            base++;
            spridx += 2;
            tx += 8;
        }
        y += 16;
    }
}
static void wait_frame(void) {
    while ((csr_read_clear(mip, (1 << 16)) & (1 << 16)) == 0);
}

int main(void) {
    console_init();

    FILE *f = fopen("/demos/tiledemo/data/tiledata.bin", "rb");
    if (!f) {
        perror("");
        exit(1);
    }
    uint16_t palette[16];
    fread((void *)TILEMAP, 0x1000, 1, f);
    fread((void *)VRAM + 0x1000, 0x3000, 1, f);
    fread(palette, sizeof(palette), 1, f);
    fclose(f);

    console_set_width(40);
    console_show_cursor(false);
    console_set_background_color(0);
    console_set_foreground_color(9);
    console_clear_screen();

    console_set_cursor_row(0);
    console_set_cursor_column(0);
    printf("  Score:xxxxx    Lives:x    Time:xxx");

    for (int i = 0; i < 16; i++)
        PALETTE[i] = palette[i];

    for (int i = 0; i < 64; i++) {
        SPRPOS[i] = 240 << 16;
    }

    // Manually patch the tilemap; give the palm tree priority, so sonic and the balls go behind it
    {
        for (int j = 0; j < 5; j++) {
            for (int i = 0; i < 5; i++) {
                TILEMAP[64 * (8 + j) + (7 + i)] |= TILEMAP_PRIO;
            }
        }
        for (int j = 0; j < 5; j++) {
            TILEMAP[64 * (13 + j) + 9] |= TILEMAP_PRIO;
        }
    }

    // Init balls at random positions
    for (uint8_t i = 0; i < NUM_BALLS; i++) {
        struct ball *ballp = &balls[i];

        ballp->x  = rand() % (320 - 16);
        ballp->y  = rand() % (240 - 16);
        ballp->dx = rand() % 5 - 2;
        ballp->dy = rand() % 5 - 2;
        if (ballp->dx == 0)
            ballp->dx = 1;
        if (ballp->dy == 0)
            ballp->dy = 1;

        setup_ball_sprites(i);
        update_ball_sprites(i);
    }

    REGS->VCTRL = VCTRL_TEXT_PRIO | VCTRL_TEXT_EN | VCTRL_SPR_EN | VCTRL_GFX_EN | VCTRL_GFX_TILEMODE;

    uint8_t anim_frame = 0;
    uint8_t anim_delay = 0;
    int     sonic_x    = 160 - 12;
    int     sonic_y    = 90;

    // REGS->VSCRY = 3;
    while (1) {
        wait_frame();
        PALETTE[0] = 0;

        REGS->VSCRX++;

        // Update Sonic sprite
        sonic_sprite(anim_frame, sonic_x, sonic_y);

        // Update Sonic animation
        anim_delay++;
        if (anim_delay >= 5) {
            anim_delay = 0;
            anim_frame++;
            if (anim_frame >= 6) {
                anim_frame = 0;
            }
        }

        // Move balls
        for (uint8_t i = 0; i < NUM_BALLS; i++) {
            struct ball *ballp = &balls[i];

            // Move ball in horizontal direction. If it hits the screen edge, reverse direction.
            ballp->x += ballp->dx;
            if (ballp->x >= 320 - 16)
                ballp->dx = -ballp->dx;

            // Move ball in vertical direction. If it hits the screen edge, reverse direction.
            ballp->y += ballp->dy;
            if (ballp->y >= 240 - 16)
                ballp->dy = -ballp->dy;

            // Update ball sprite
            update_ball_sprites(i);
        }
        PALETTE[0] = palette[0];
    }

    return 0;
}
