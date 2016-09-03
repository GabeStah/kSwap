# kSwap

Broker-based World of Warcraft addon that allows the user to easily swap between Specializations while simultaneously swapping to an Equipment Set with the same name.

## Features

- One-click specialization swap via broker popout.
- (Optional) Simultaneous equipment set swap immediately after specialization swap.

## Installation

Place `kSwap` directory in `<World of Warcraft Directory>\Interface\AddOns\`, such that the final installation path is: `<World of Warcraft Directory>\Interface\AddOns\kSwap`.

If a broker addon is installed, `kSwap` should appear automatically with the icon and name matching your current specialization.

If no broker addon is installed, a minimap attached icon will appear instead.

## Configuration

`Right-click` on the broker icon/name will open the simple configuration options.

- `Minimap Icon` determines whether the minimap icon will appear (if not broker addon is installed).
- `Swap Equipment Set` determines if `kSwap` will attempt to swap the active Equipment Set after specialization is swapped as well.  _Note: Equipment Sets **must** have the same names as associated Specializations._

## Usage

Hover over the `kSwap` broker icon to see the popout displaying your available specializations.

A green `checkmark` indicates which specialization is currently selected.

If `Swap Equipment Set` option is also selected, a `blue shield` icon indicates which gear set is equipped as well.

To swap specialization (and equipment set), simply left click the desired specialization.
