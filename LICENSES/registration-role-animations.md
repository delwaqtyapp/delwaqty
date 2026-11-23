# Registration role animation assets

Checked 2026-11-23. These assets are bundled locally. No network, paid plan,
subscription, or attribution requirement is needed to display them in the app.
The Lottie Simple License allows commercial use and modification. The files
and any modified derivatives retain that license, not the repository's code
license. Full terms: `LICENSES/Lottie-Simple-License.txt`.

| Bundled file | Creator | Source | License | Bytes |
| --- | --- | --- | --- | ---: |
| assets/lottie/roles/scooter.lottie | Priyanshu Rijhwani | https://lottiefiles.com/free-animation/scooter-d72sIa1LQJ | Lottie Simple License FL 9.13.21 | 7344 |
| assets/lottie/roles/shopper.lottie | Sheikh Sohel | https://lottiefiles.com/free-animation/girl-walking-with-bag-PggTijzEQr | Lottie Simple License FL 9.13.21 | 18697 |
| assets/lottie/roles/market.lottie | Abdul Latif | https://lottiefiles.com/free-animation/food-stand-seller-and-buyer-at-local-market-XFAZAyKtoK | Lottie Simple License FL 9.13.21 | 46393 |

License source: https://lottiefiles.com/page/license

All three files are unmodified source dotLottie archives, each under 100KB.
The compressed market archive expands to about 481KB JSON. Animation colors
remain those of the original artists; role card borders and accents retain
the existing four role colors. These source palettes do not exactly match
those colors.

The doctor, carpenter, electrician, teacher, butcher and dairy scenes are
original native Flutter drawings in `role_illustration.dart`. No third-party
art is used for those scenes. A downloaded Doctor Avatar candidate by Norma
was rejected after it rendered blank in Flutter; it is not bundled. A carpenter
tool-icon candidate was rejected because it did not depict a working person.
No in-app attribution line is required by the licenses of the bundled assets.

Playback uses the existing lottie dependency. A 12-second cycle shows four
provider professions and four merchant scenes. Motion stops when the widget
is off-screen (checked every 600ms), its route is covered, the app goes to the
background, TickerMode disables it, or reduced-motion is requested. Drawing
is confined to RepaintBoundary. The CPU/memory cost has not been profiled on
a real low-end Android device.
