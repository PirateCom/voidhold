import type { ReactNode } from "react";
import atlas from "../../public/sprites/voidhold.json";

const SHEET = "/sprites/voidhold_sprite.jpg";
const SPRITE_SIZE = 96;

/** New art in public/img — mines, power, storage, facilities, defences, research, ships. */
const FILE_SPRITES: Record<string, string> = {
  ore_mine: "/img/mine/ore_mine.jpg",
  crystal_mine: "/img/mine/crystal_mine.jpg",
  deuterium_extractor: "/img/mine/deut_mine.jpg",
  power_plant: "/img/power/power_plant.jpg",
  fusion_reactor: "/img/power/fusion_reactor.jpg",
  ore_storage: "/img/storage/ore_storage.jpg",
  crystal_storage: "/img/storage/crystal_storage.jpg",
  deuterium_storage: "/img/storage/deut_storage.jpg",
  robotics_factory: "/img/facilities/robotics_factory.jpg",
  shipyard: "/img/facilities/shipyard.jpg",
  research_lab: "/img/facilities/research_lab.jpg",
  missile_silo: "/img/facilities/missle_silo.jpg",
  nanite_factory: "/img/facilities/nanite_fctory.jpg",
  terraformer: "/img/facilities/terraformer.jpg",
  rocket_launcher: "/img/defences/rocketlauncher.jpg",
  light_laser: "/img/defences/lightlaser.jpg",
  heavy_laser: "/img/defences/heavylaser.jpg",
  gauss_cannon: "/img/defences/gaussiancannon.jpg",
  ion_cannon: "/img/defences/ioncannon.jpg",
  plasma_turret: "/img/defences/plasmaturret.jpg",
  small_shield_dome: "/img/defences/small dome.jpg",
  large_shield_dome: "/img/defences/large dome.jpg",
  antiballistic_missile: "/img/defences/antiballistic missle.jpg",
  interplanetary_missile: "/img/defences/interplanetary missle.jpg",
  energy_tech: "/img/research/research_energy.jpg",
  laser_tech: "/img/research/research_laser.jpg",
  ion_tech: "/img/research/research_ion.jpg",
  hyperspace_tech: "/img/research/research_Hyperspace technology.jpg",
  plasma_tech: "/img/research/research_greenplasma.jpg",
  combustion_drive: "/img/research/research_combustion.jpg",
  impulse_drive: "/img/research/research_impulsedrive.jpg",
  hyperspace_drive: "/img/research/research_hyperspace.jpg",
  espionage_tech: "/img/research/research_espionage.jpg",
  computer_tech: "/img/research/research_cpu.jpg",
  astrophysics: "/img/research/research_astronomy.jpg",
  graviton_tech: "/img/research/research_gravity.jpg",
  weapons_tech: "/img/research/research_weapons.jpg",
  shielding_tech: "/img/research/research_shield.jpg",
  armour_tech: "/img/research/research_armor.jpg",
  light_fighter: "/img/ships/ship_fighter.jpg",
  heavy_fighter: "/img/ships/ship_fighter.jpg",
};

type AtlasSprite = {
  id: string;
  x: number | null;
  y: number | null;
  w: number | null;
  h: number | null;
};

function atlasSprite(id: string): AtlasSprite | undefined {
  const sprite = (atlas.sprites as AtlasSprite[]).find((entry) => entry.id === id);
  if (
    !sprite ||
    sprite.x == null ||
    sprite.y == null ||
    sprite.w == null ||
    sprite.h == null ||
    sprite.w <= 0 ||
    sprite.h <= 0
  ) {
    return undefined;
  }
  return sprite;
}

function SpriteArtFill({ id }: { id: string }) {
  const file = FILE_SPRITES[id];
  if (file) {
    return (
      // eslint-disable-next-line @next/next/no-img-element
      <img
        src={encodeURI(file)}
        alt=""
        className="pointer-events-none absolute inset-0 h-full w-full object-cover object-center"
      />
    );
  }
  const sprite = atlasSprite(id);
  if (!sprite || sprite.x == null || sprite.y == null || sprite.w == null || sprite.h == null) {
    return (
      <div className="absolute inset-0 flex items-center justify-center bg-black/40 px-4 text-center text-xs uppercase tracking-wide text-[var(--muted-fg)]">
        {id.replace(/_/g, " ")}
      </div>
    );
  }
  return (
    <div className="absolute inset-0 overflow-hidden bg-black/40 [container-type:size]">
      <div
        aria-hidden
        className="absolute top-1/2 left-1/2"
        style={{
          width: sprite.w,
          height: sprite.h,
          marginLeft: -sprite.w / 2,
          marginTop: -sprite.h / 2,
          backgroundImage: `url(${SHEET})`,
          backgroundRepeat: "no-repeat",
          backgroundPosition: `-${sprite.x}px -${sprite.y}px`,
          transform: `scale(max(100cqw / ${sprite.w}, 100cqh / ${sprite.h}))`,
        }}
      />
    </div>
  );
}

export function SpriteHero({
  id,
  title,
  badge,
}: {
  id: string;
  title: string;
  badge?: ReactNode;
}) {
  return (
    <div className="relative aspect-[4/3] w-full">
      <SpriteArtFill id={id} />
      <div className="absolute inset-x-0 bottom-0 bg-gradient-to-t from-[#0b1221] from-10% to-transparent px-4 pt-12 pb-3">
        <div className="flex items-end justify-between gap-3">
          <h2 className="font-semibold drop-shadow-[0_1px_8px_rgba(0,0,0,0.8)]">{title}</h2>
          {badge != null ? <span className="sci-badge shrink-0">{badge}</span> : null}
        </div>
      </div>
    </div>
  );
}

export function SpriteThumb({ id }: { id: string }) {
  const file = FILE_SPRITES[id];
  if (file) {
    return (
      <div
        className="relative shrink-0 overflow-hidden rounded-xl border border-[var(--border)] bg-black/40"
        style={{ width: SPRITE_SIZE, height: SPRITE_SIZE }}
      >
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src={encodeURI(file)} alt="" className="h-full w-full object-cover" />
      </div>
    );
  }

  const sprite = atlasSprite(id);
  if (!sprite || sprite.x == null || sprite.y == null || sprite.w == null || sprite.h == null) {
    return (
      <div
        className="flex shrink-0 items-center justify-center rounded-xl border border-[var(--border)] bg-black/40 px-2 text-center text-[10px] uppercase tracking-wide text-[var(--muted-fg)]"
        style={{ width: SPRITE_SIZE, height: SPRITE_SIZE }}
      >
        {id.replace(/_/g, " ")}
      </div>
    );
  }
  const scale = SPRITE_SIZE / sprite.w;
  return (
    <div
      className="relative shrink-0 overflow-hidden rounded-xl border border-[var(--border)] bg-black/40"
      style={{ width: SPRITE_SIZE, height: Math.round(SPRITE_SIZE * (sprite.h / sprite.w)) }}
    >
      <div
        aria-hidden
        className="absolute top-0 left-0"
        style={{
          width: sprite.w,
          height: sprite.h,
          backgroundImage: `url(${SHEET})`,
          backgroundRepeat: "no-repeat",
          backgroundPosition: `-${sprite.x}px -${sprite.y}px`,
          transform: `scale(${scale})`,
          transformOrigin: "top left",
        }}
      />
    </div>
  );
}
