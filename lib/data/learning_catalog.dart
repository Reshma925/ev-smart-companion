import 'package:flutter/material.dart';

import '../models/learning_lesson.dart';

final learningCategories = <LearningCategory>[
  LearningCategory(
    id: 'basics',
    title: 'EV BASICS',
    subtitle: 'Understand how EVs work',
    icon: Icons.electric_car_rounded,
    lessons: [
      LearningLesson(
        id: 'how-ev-works',
        title: 'How an EV works',
        introduction: 'An electric vehicle turns stored electrical energy into motion.',
        explanation:
            'Energy from the battery flows through power electronics to an electric motor. The motor turns the wheels, while control systems manage power and keep the vehicle operating within safe limits.',
        keyPoints: [
          'The battery stores energy for driving.',
          'Power electronics control energy between the battery and motor.',
          'The motor converts electrical energy into wheel motion.',
        ],
        icon: Icons.electric_car_rounded,
      ),
      LearningLesson(
        id: 'electric-motor',
        title: 'The electric motor',
        introduction: 'An electric motor delivers smooth, responsive drive.',
        explanation:
            'The motor uses magnetic forces to rotate. It can provide useful torque from low speeds, which is why an EV often feels responsive when moving away from a stop.',
        keyPoints: [
          'The motor can drive the wheels without a multi-speed gearbox in many EVs.',
          'Motor control determines how much power reaches the wheels.',
        ],
        icon: Icons.settings_input_component_rounded,
      ),
      LearningLesson(
        id: 'ev-battery',
        title: 'The EV battery',
        introduction: 'The traction battery is the main energy store for driving.',
        explanation:
            'An EV battery is made of many cells grouped into modules and packs. The usable energy and chemistry vary by vehicle, so the owner manual is the best source for model-specific limits.',
        keyPoints: [
          'Battery capacity is commonly expressed in kilowatt-hours (kWh).',
          'The traction battery is different from a small 12-volt accessory battery.',
        ],
        icon: Icons.battery_charging_full_rounded,
      ),
      LearningLesson(
        id: 'battery-management',
        title: 'Battery Management System',
        introduction: 'A Battery Management System monitors and manages the battery pack.',
        explanation:
            'The BMS monitors cell conditions such as voltage and temperature, estimates state of charge, and coordinates protective limits with the vehicle. It helps the pack operate within its designed operating range.',
        keyPoints: [
          'It monitors cells and pack conditions.',
          'It supports safe charging and discharging limits.',
          'Its estimates are useful, but can change as conditions change.',
        ],
        icon: Icons.monitor_heart_outlined,
      ),
      LearningLesson(
        id: 'regenerative-braking',
        title: 'Regenerative braking',
        introduction: 'Regeneration can recover some energy while slowing down.',
        explanation:
            'During regenerative braking, the motor operates as a generator and sends some kinetic energy back to the battery. Friction brakes still provide stopping power when needed.',
        keyPoints: [
          'Regeneration varies by vehicle, battery state and driving conditions.',
          'It does not mean every braking event returns all energy used.',
        ],
        icon: Icons.replay_rounded,
      ),
      LearningLesson(
        id: 'meaning-of-kwh',
        title: 'What kWh means',
        introduction: 'A kilowatt-hour is a measure of energy.',
        explanation:
            'Power is the rate energy is used or delivered; energy is the total amount. A 1 kW load running for one hour uses 1 kWh. Battery capacity and electricity consumption are often described in kWh.',
        keyPoints: [
          'kW describes power.',
          'kWh describes energy.',
          'Vehicle efficiency may be displayed as distance per kWh or kWh per distance.',
        ],
        icon: Icons.bolt_rounded,
      ),
      LearningLesson(
        id: 'ac-vs-dc',
        title: 'AC and DC electricity',
        introduction: 'EV charging uses AC or DC depending on the charger.',
        explanation:
            'With AC charging, the vehicle’s onboard charger converts incoming AC to battery-compatible DC. A DC fast charger performs conversion in the charging equipment and supplies DC to the vehicle within the limits both systems allow.',
        keyPoints: [
          'AC charging conversion happens in the vehicle.',
          'DC charging uses conversion equipment outside the vehicle.',
          'The vehicle and charger jointly determine charging power.',
        ],
        icon: Icons.electrical_services_rounded,
      ),
      LearningLesson(
        id: 'efficiency-factors',
        title: 'What affects EV efficiency?',
        introduction: 'Efficiency changes with the vehicle and its operating conditions.',
        explanation:
            'Speed, acceleration, road gradient, temperature, tires, payload and cabin heating or cooling all affect energy use. Compare trips in similar conditions rather than treating one estimate as a fixed rating.',
        keyPoints: [
          'Higher speeds generally increase aerodynamic energy demand.',
          'Cabin climate control and cold or hot conditions can change consumption.',
          'Tire condition and pressure affect rolling resistance.',
        ],
        icon: Icons.speed_rounded,
      ),
    ],
  ),
  LearningCategory(
    id: 'battery-range',
    title: 'BATTERY & RANGE',
    subtitle: 'Get more from your battery',
    icon: Icons.battery_6_bar_rounded,
    lessons: [
      LearningLesson(
        id: 'battery-percentage',
        title: 'Understanding battery percentage',
        introduction: 'Battery percentage is an estimate of the pack’s state of charge.',
        explanation:
            'The displayed percentage indicates an estimate of how much usable energy remains relative to the vehicle’s defined usable capacity. It is not a direct measurement of distance remaining.',
        keyPoints: [
          'Percentage and driving range are related but are not interchangeable.',
          'The vehicle may limit how much of the physical battery capacity is available.',
        ],
        icon: Icons.battery_full_rounded,
      ),
      LearningLesson(
        id: 'estimated-range',
        title: 'Understanding estimated driving range',
        introduction: 'Displayed range is an estimate, not a guaranteed distance.',
        explanation:
            'The vehicle estimates how far it may travel using its state of charge and assumptions about energy use. Recent driving and current conditions can influence the estimate.',
        keyPoints: [
          'Use range as a planning aid, not a promise.',
          'Route, weather, speed and cabin use can change actual results.',
        ],
        icon: Icons.route_rounded,
      ),
      LearningLesson(
        id: 'why-range-changes',
        title: 'Why estimated range changes',
        introduction: 'Range can move even when battery percentage changes only slightly.',
        explanation:
            'The estimate adapts to energy consumption. A recent efficient drive may raise the estimate; high-speed, uphill or climate-heavy driving may lower it. Temperature and battery conditioning also affect energy available for driving.',
        keyPoints: [
          'A changing estimate does not necessarily indicate a battery fault.',
          'Look at trends across comparable trips.',
        ],
        icon: Icons.show_chart_rounded,
      ),
      LearningLesson(
        id: 'range-factors',
        title: 'Factors affecting range',
        introduction: 'Many everyday conditions influence how far a charge will take you.',
        explanation:
            'Driving speed, stop-and-go traffic, elevation, wind, tire pressure, payload, temperature and HVAC use can affect energy consumption. The effect differs between vehicles and journeys.',
        keyPoints: [
          'Plan extra margin for unfamiliar routes and changing conditions.',
          'Check tires and remove unnecessary payload when practical.',
        ],
        icon: Icons.tune_rounded,
      ),
      LearningLesson(
        id: 'speed-range',
        title: 'Driving speed and range',
        introduction: 'Speed can have a significant effect on energy use.',
        explanation:
            'At higher speeds, aerodynamic resistance rises, requiring more energy to maintain speed. A steady, moderate pace within road rules can help reduce energy demand.',
        keyPoints: [
          'Allow extra travel time instead of trying to recover it with speed.',
          'Road and weather conditions still determine the safe speed.',
        ],
        icon: Icons.speed_rounded,
      ),
      LearningLesson(
        id: 'hvac-range',
        title: 'Heating, cooling and range',
        introduction: 'Cabin comfort systems use energy from the vehicle.',
        explanation:
            'Heating and cooling can increase energy demand, especially when there is a large difference between cabin and outdoor temperatures. Some vehicles offer preconditioning while plugged in; follow your vehicle guidance.',
        keyPoints: [
          'Use comfortable settings rather than disabling safety-critical visibility or comfort.',
          'Preconditioning options vary by vehicle.',
        ],
        icon: Icons.thermostat_rounded,
      ),
      LearningLesson(
        id: 'weather-range',
        title: 'Weather and range',
        introduction: 'Cold, heat, wind and rain can affect energy use.',
        explanation:
            'Temperature affects battery and cabin conditioning needs. Wind, wet roads and snow can also increase resistance. The amount of change depends on the vehicle, route and conditions.',
        keyPoints: [
          'Expect estimates to vary seasonally.',
          'Check weather and preserve additional range for difficult conditions.',
        ],
        icon: Icons.cloud_outlined,
      ),
      LearningLesson(
        id: 'battery-degradation',
        title: 'Battery degradation',
        introduction: 'Battery capacity can gradually change with age and use.',
        explanation:
            'All batteries age over time. Temperature exposure, charging patterns, energy throughput and chemistry can influence long-term capacity. A single range estimate cannot diagnose battery condition.',
        keyPoints: [
          'Use the vehicle’s health information and service guidance for assessment.',
          'Consult an authorized service provider if you notice a persistent abnormal change.',
        ],
        icon: Icons.monitor_heart_rounded,
      ),
      LearningLesson(
        id: 'charging-practices',
        title: 'Good battery charging practices',
        introduction: 'Follow the charging guidance provided for your vehicle.',
        explanation:
            'Recommended charge limits and storage practices differ by model and battery chemistry. Use the owner manual’s guidance, avoid leaving the vehicle at extreme states of charge longer than advised, and use approved charging equipment.',
        keyPoints: [
          'Use manufacturer-recommended charge limits.',
          'For long storage, follow the manual’s target state of charge.',
        ],
        icon: Icons.battery_charging_full_rounded,
      ),
      LearningLesson(
        id: 'minimum-safety-reserve',
        title: 'Minimum safety reserve',
        introduction: 'A reserve is a deliberate margin for reaching your destination or charger.',
        explanation:
            'The minimum safety reserve is the minimum battery/range you intentionally keep available so the vehicle does not reach 0% before reaching the destination or charging station. Set a margin that considers route uncertainty, weather, traffic and charger availability.',
        keyPoints: [
          'A reserve is a planning margin, not extra battery capacity.',
          'Increase the margin when route or charger conditions are uncertain.',
        ],
        icon: Icons.shield_outlined,
      ),
    ],
  ),
  LearningCategory(
    id: 'charging',
    title: 'CHARGING',
    subtitle: 'Learn charging fundamentals',
    icon: Icons.ev_station_rounded,
    lessons: [
      LearningLesson(
        id: 'charging-works',
        title: 'How EV charging works',
        introduction: 'Charging transfers electrical energy into the vehicle battery.',
        explanation:
            'The vehicle and charging equipment communicate to check compatibility and limits. Charging power may change during a session based on battery state, temperature and equipment capability.',
        keyPoints: [
          'Use compatible, undamaged charging equipment.',
          'The vehicle controls its safe charging limits.',
        ],
        icon: Icons.ev_station_rounded,
      ),
      LearningLesson(
        id: 'ac-charging',
        title: 'AC charging',
        introduction: 'AC charging is commonly used at home and many destination chargers.',
        explanation:
            'The vehicle’s onboard charger converts AC power into DC for the battery. Maximum AC charging speed depends on the supply, cable or station, and the vehicle’s onboard charger.',
        keyPoints: [
          'The lowest limit in the setup may constrain charging speed.',
          'Use a properly installed supply and approved equipment.',
        ],
        icon: Icons.power_rounded,
      ),
      LearningLesson(
        id: 'dc-fast-charging',
        title: 'DC fast charging',
        introduction: 'DC fast chargers can supply energy directly to the battery system.',
        explanation:
            'A DC charger performs power conversion in the charging equipment. The vehicle manages the session and may reduce power as the battery fills or if temperature and equipment limits require it.',
        keyPoints: [
          'Peak advertised power is not maintained throughout every session.',
          'Connector, vehicle, charger and battery conditions affect the rate.',
        ],
        icon: Icons.bolt_rounded,
      ),
      LearningLesson(
        id: 'charging-speed',
        title: 'Understanding charging speed',
        introduction: 'Charging speed is a rate of energy transfer, often shown in kW.',
        explanation:
            'The delivered power depends on the charger, vehicle, battery state and temperature, and site supply. Charging power often tapers at higher states of charge to manage the battery.',
        keyPoints: [
          'A higher rated charger does not guarantee that the vehicle will use its full rating.',
          'Power and energy are different quantities.',
        ],
        icon: Icons.speed_rounded,
      ),
      LearningLesson(
        id: 'charging-time',
        title: 'Estimating charging time',
        introduction: 'Charging time depends on more than battery capacity alone.',
        explanation:
            'A rough estimate considers energy needed and average charging power, but real sessions also include power taper, temperature, vehicle limits and station conditions. Use the vehicle or station estimate for a current session.',
        keyPoints: [
          'A simple capacity ÷ peak-power calculation is only a rough upper-level estimate.',
          'Plan for connection, payment and possible waiting time.',
        ],
        icon: Icons.timer_outlined,
      ),
      LearningLesson(
        id: 'charging-costs',
        title: 'Understanding charging costs',
        introduction: 'Charging prices can be based on energy, time, session or a combination.',
        explanation:
            'Tariffs differ by provider and location. Check the rate shown before starting and consider parking, idle or connection fees where applicable. Home charging cost depends on your electricity tariff and energy used.',
        keyPoints: [
          'Review the current tariff before charging.',
          'A vehicle efficiency estimate helps compare energy use, not provider prices.',
        ],
        icon: Icons.currency_rupee_rounded,
      ),
      LearningLesson(
        id: 'charging-etiquette',
        title: 'Charging etiquette',
        introduction: 'Consider other drivers when using shared charging equipment.',
        explanation:
            'Park only in designated charging spaces while charging, move the vehicle when it is finished and no longer needs the connector, and leave cables and equipment as you found them.',
        keyPoints: [
          'Follow site signs and operator instructions.',
          'Avoid occupying a charger after your session is complete.',
        ],
        icon: Icons.people_alt_outlined,
      ),
      LearningLesson(
        id: 'charging-session',
        title: 'What happens during a charging session?',
        introduction: 'A session includes connection, authorization, energy transfer and completion.',
        explanation:
            'The charger and vehicle establish communication and safety checks, authorize the session, exchange energy within agreed limits, and stop when requested or when a limit is reached. Exact steps vary by charger.',
        keyPoints: [
          'Follow the charger display and vehicle instructions.',
          'If a session fails, use the operator’s support information.',
        ],
        icon: Icons.sync_alt_rounded,
      ),
      LearningLesson(
        id: 'charging-status',
        title: 'Understanding charging status',
        introduction: 'Status messages indicate what the charger or vehicle is doing.',
        explanation:
            'A status may show preparing, charging, paused, complete or a fault. The source of truth for an active session is the vehicle display and charger interface; status names differ between systems.',
        keyPoints: [
          'Check both the vehicle and charger if their status appears inconsistent.',
          'Do not handle damaged connectors or cables.',
        ],
        icon: Icons.info_outline_rounded,
      ),
      LearningLesson(
        id: 'charging-cards',
        title: 'Understanding charging cards',
        introduction: 'Some charging networks use an account or card to authorize a session.',
        explanation:
            'A charging card or app may identify your account to a participating operator. Network coverage, payment, balances and transaction records depend on the provider and your account settings.',
        keyPoints: [
          'Confirm that the card or app is accepted at the station.',
          'The app’s Charging section manages your actual card and transactions.',
        ],
        icon: Icons.credit_card_rounded,
      ),
    ],
  ),
  LearningCategory(
    id: 'smart-driving',
    title: 'SMART DRIVING',
    subtitle: 'Improve efficiency',
    icon: Icons.eco_outlined,
    lessons: [
      LearningLesson(
        id: 'efficient-acceleration',
        title: 'Efficient acceleration',
        introduction: 'Gentle, planned acceleration can avoid unnecessary energy demand.',
        explanation:
            'Rapid acceleration uses power quickly. Smoothly building speed when traffic and road conditions allow can help make energy use more predictable.',
        keyPoints: [
          'Accelerate smoothly and leave space to react.',
          'Always prioritize safe traffic flow over efficiency targets.',
        ],
        icon: Icons.trending_up_rounded,
        practicalTip: 'Smooth acceleration and braking can reduce unnecessary energy consumption.',
      ),
      LearningLesson(
        id: 'steady-speed',
        title: 'Maintaining a steady speed',
        introduction: 'A consistent pace can make energy use easier to manage.',
        explanation:
            'Frequent speed changes require repeated acceleration. Anticipate traffic and maintain a legal, safe pace when conditions permit.',
        keyPoints: [
          'Use cruise assistance only when appropriate and attentive.',
          'Road conditions and speed limits always take priority.',
        ],
        icon: Icons.speed_rounded,
      ),
      LearningLesson(
        id: 'smart-regeneration',
        title: 'Using regenerative braking',
        introduction: 'Regeneration can recapture part of the vehicle’s motion energy.',
        explanation:
            'Look ahead and lift off early when it is safe so regeneration can slow the vehicle smoothly. The friction brakes remain important and should be used as needed.',
        keyPoints: [
          'Regeneration does not replace safe braking.',
          'Its strength and availability vary by vehicle and battery state.',
        ],
        icon: Icons.replay_rounded,
      ),
      LearningLesson(
        id: 'highway-city-efficiency',
        title: 'Highway and city efficiency',
        introduction: 'Different routes create different energy-use patterns.',
        explanation:
            'City traffic may allow regenerative recovery during deceleration, while highway driving often involves sustained higher speed and aerodynamic resistance. Traffic, elevation and weather can change either pattern.',
        keyPoints: [
          'Do not assume one setting or route type is always more efficient.',
          'Compare similar journeys using your vehicle’s trip data.',
        ],
        icon: Icons.alt_route_rounded,
      ),
      LearningLesson(
        id: 'driving-hvac',
        title: 'Climate control while driving',
        introduction: 'Use cabin comfort features thoughtfully.',
        explanation:
            'Climate systems consume energy, but safe visibility and driver comfort matter. Use the vehicle’s efficient climate features when available and follow manufacturer guidance.',
        keyPoints: [
          'Never compromise windshield visibility for an efficiency target.',
          'Climate system efficiency varies by vehicle.',
        ],
        icon: Icons.air_rounded,
      ),
      LearningLesson(
        id: 'tire-pressure',
        title: 'Tire pressure and efficiency',
        introduction: 'Correct tire pressure supports handling and rolling efficiency.',
        explanation:
            'Underinflated tires can increase rolling resistance and may affect wear and handling. Check pressure when tires are cold and use the vehicle manufacturer’s recommended values.',
        keyPoints: [
          'Use the pressure on the vehicle placard or manual, not the tire sidewall maximum.',
          'Inspect tires regularly for damage and wear.',
        ],
        icon: Icons.tire_repair_rounded,
      ),
      LearningLesson(
        id: 'driving-style-energy',
        title: 'Driving style and energy use',
        introduction: 'Small driving choices influence trip energy demand.',
        explanation:
            'Speed, acceleration, braking and anticipating traffic can affect energy use. The best approach is a safe, smooth driving style suited to current conditions.',
        keyPoints: [
          'Keep a safe following distance.',
          'Avoid abrupt maneuvers and unnecessary high speed.',
        ],
        icon: Icons.directions_car_filled_outlined,
      ),
      LearningLesson(
        id: 'maximize-range',
        title: 'How to maximize range',
        introduction: 'Range planning is a combination of preparation and driving.',
        explanation:
            'Check tire pressure, plan charging stops, account for weather and elevation, and drive smoothly at legal speeds. There is no single setting that guarantees a specific range.',
        keyPoints: [
          'Keep a reserve for route changes and charger availability.',
          'Use the vehicle’s trip and energy information to learn its real-world patterns.',
        ],
        icon: Icons.navigation_rounded,
      ),
    ],
  ),
  LearningCategory(
    id: 'vehicle-health',
    title: 'VEHICLE HEALTH',
    subtitle: 'Understand your EV’s health',
    icon: Icons.health_and_safety_outlined,
    lessons: [
      LearningLesson(
        id: 'battery-health',
        title: 'Battery health',
        introduction: 'Battery health describes condition and capacity relative to the battery’s earlier life.',
        explanation:
            'Health estimates may use different methods and are not direct measurements of every cell. Treat trends and vehicle alerts seriously, and ask a qualified service provider about persistent concerns.',
        keyPoints: [
          'A health percentage is an estimate, not a complete diagnosis.',
          'Temperature and usage history influence long-term battery behavior.',
        ],
        icon: Icons.battery_alert_outlined,
      ),
      LearningLesson(
        id: 'brake-health',
        title: 'Brake health',
        introduction: 'EV braking combines regenerative and friction braking.',
        explanation:
            'Friction brakes remain essential for stopping and may be used less often when regeneration is strong. Follow inspection schedules and report unusual noise, vibration or warning indicators.',
        keyPoints: [
          'Regeneration does not eliminate brake maintenance.',
          'Follow your vehicle’s service interval.',
        ],
        icon: Icons.car_repair_rounded,
      ),
      LearningLesson(
        id: 'tire-health',
        title: 'Tire health',
        introduction: 'Tires affect safety, handling, comfort and energy use.',
        explanation:
            'EV torque and vehicle weight can influence tire wear. Check pressure and tread condition regularly and use the tire specification recommended for your vehicle.',
        keyPoints: [
          'Inspect for uneven wear, damage and low tread.',
          'Have alignment or persistent pressure loss checked.',
        ],
        icon: Icons.tire_repair_rounded,
      ),
      LearningLesson(
        id: 'motor-health',
        title: 'Motor and power electronics',
        introduction: 'The drive motor and power electronics deliver controlled propulsion.',
        explanation:
            'These systems are designed for long service, but warning indicators or unusual behavior should be assessed using manufacturer guidance. Do not attempt high-voltage repairs yourself.',
        keyPoints: [
          'High-voltage components require trained service personnel.',
          'Pay attention to vehicle alerts and service instructions.',
        ],
        icon: Icons.settings_rounded,
      ),
      LearningLesson(
        id: 'service-indicators',
        title: 'Service indicators',
        introduction: 'Service reminders help you follow maintenance schedules.',
        explanation:
            'A service reminder may be based on time, distance or a vehicle-specific condition. Check the owner manual for what it means and arrange service as recommended.',
        keyPoints: [
          'A reminder is not always an emergency warning.',
          'Do not ignore a persistent service alert.',
        ],
        icon: Icons.build_circle_outlined,
      ),
      LearningLesson(
        id: 'warning-indicators',
        title: 'Warning indicators',
        introduction: 'Dashboard warnings communicate conditions that may need attention.',
        explanation:
            'Warning colors and symbols vary by manufacturer. Follow the exact instruction shown in your vehicle manual. If the vehicle says to stop or seek assistance, follow that direction.',
        keyPoints: [
          'Never rely on a general lesson to interpret a model-specific warning.',
          'Use the owner manual and authorized support for urgent alerts.',
        ],
        icon: Icons.warning_amber_rounded,
      ),
      LearningLesson(
        id: 'regular-maintenance',
        title: 'Why regular maintenance matters',
        introduction: 'EVs still need inspections and routine care.',
        explanation:
            'Tires, brakes, cabin filters, coolant systems and other components may need checks according to the vehicle schedule. Regular maintenance can help identify wear and preserve safe operation.',
        keyPoints: [
          'Maintenance needs vary by model and use.',
          'Follow the service schedule in the owner manual.',
        ],
        icon: Icons.event_note_rounded,
      ),
      LearningLesson(
        id: 'health-efficiency',
        title: 'Health, efficiency and range',
        introduction: 'Tire, brake and battery condition can influence driving efficiency.',
        explanation:
            'Tire pressure and alignment affect rolling resistance; dragging brakes can create unwanted resistance; battery condition affects available energy. Persistent changes deserve a proper inspection rather than guesswork.',
        keyPoints: [
          'Use vehicle diagnostics and service professionals for real assessments.',
          'Learn what each displayed metric means, but do not treat it as a diagnosis.',
        ],
        icon: Icons.insights_rounded,
      ),
    ],
  ),
  LearningCategory(
    id: 'environment',
    title: 'EV & ENVIRONMENT',
    subtitle: 'Learn about sustainable mobility',
    icon: Icons.public_rounded,
    lessons: [
      LearningLesson(
        id: 'ev-vs-ice',
        title: 'EV and combustion vehicles',
        introduction: 'EVs and internal-combustion vehicles use different powertrains.',
        explanation:
            'A battery EV uses stored electricity and an electric motor. A combustion vehicle burns fuel in an engine. A full environmental comparison depends on vehicle manufacture, energy or fuel supply, use, and end-of-life impacts.',
        keyPoints: [
          'Vehicle lifecycle and local energy sources matter to comparisons.',
          'Avoid assuming one figure applies everywhere.',
        ],
        icon: Icons.compare_arrows_rounded,
      ),
      LearningLesson(
        id: 'energy-efficiency',
        title: 'Energy efficiency',
        introduction: 'Efficiency describes how much useful travel comes from energy used.',
        explanation:
            'Tracking energy per distance can help compare driving conditions and habits. The displayed unit and measurement method vary, so compare like with like.',
        keyPoints: [
          'Lower energy use for the same journey means higher vehicle energy efficiency.',
          'Driving conditions and accessory use influence the result.',
        ],
        icon: Icons.bolt_rounded,
      ),
      LearningLesson(
        id: 'environment-regeneration',
        title: 'Regeneration and energy recovery',
        introduction: 'Regenerative braking changes some motion energy into electrical energy.',
        explanation:
            'Regeneration can reduce energy otherwise lost during deceleration, but conversion is not lossless. Smooth anticipation also helps avoid unnecessary acceleration and braking.',
        keyPoints: [
          'Recovered energy depends on conditions and system limits.',
          'Safety remains more important than maximizing regeneration.',
        ],
        icon: Icons.replay_circle_filled_outlined,
      ),
      LearningLesson(
        id: 'electricity-usage',
        title: 'Understanding electricity use',
        introduction: 'Charging draws electricity from a supply to replenish the battery.',
        explanation:
            'The electricity source and grid mix vary by location and time. Charging losses mean electricity taken from a supply and energy later available at the battery are not always identical.',
        keyPoints: [
          'Energy sources differ between electricity systems.',
          'Use your local utility information for local generation details.',
        ],
        icon: Icons.electrical_services_outlined,
      ),
      LearningLesson(
        id: 'sustainable-driving',
        title: 'Sustainable driving choices',
        introduction: 'Efficient driving can reduce energy use for a given trip.',
        explanation:
            'Planning routes, maintaining tires and driving smoothly can reduce avoidable energy demand. Broader sustainability also includes vehicle production, energy supply and responsible battery lifecycle management.',
        keyPoints: [
          'Efficiency is one part of a broader environmental picture.',
          'Avoid claims that ignore local and lifecycle differences.',
        ],
        icon: Icons.eco_rounded,
      ),
      LearningLesson(
        id: 'environment-considerations',
        title: 'Environmental considerations',
        introduction: 'Vehicle impacts occur across manufacturing, use and end of life.',
        explanation:
            'Materials, manufacturing energy, electricity generation, maintenance and recycling all matter. Impacts differ by region and vehicle, so use transparent lifecycle studies for quantitative comparisons.',
        keyPoints: [
          'A fair comparison defines its assumptions and geographic scope.',
          'Battery reuse and recycling systems continue to develop.',
        ],
        icon: Icons.recycling_rounded,
      ),
      LearningLesson(
        id: 'why-efficiency-matters',
        title: 'Why EV efficiency matters',
        introduction: 'Efficiency affects energy demand and the distance available from a charge.',
        explanation:
            'Using energy efficiently can reduce charging frequency and total electricity demand for travel. It also makes trip planning more predictable, while actual environmental outcomes depend on the energy source and lifecycle.',
        keyPoints: [
          'Efficiency benefits are practical and measurable in energy use.',
          'Avoid assuming efficiency alone describes total environmental impact.',
        ],
        icon: Icons.insights_outlined,
      ),
    ],
  ),
];
