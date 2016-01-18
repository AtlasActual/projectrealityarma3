/**
 * Initialise un v�hicule h�liporteur
 * 
 * @param 0 l'h�liporteur
 */

private ["_heliporteur"];

_heliporteur = _this select 0;

// D�finition locale de la variable si elle n'est pas d�finie sur le r�seau
if (isNil {_heliporteur getVariable "R3F_LOG_heliporte"}) then
{
	_heliporteur setVariable ["R3F_LOG_heliporte", objNull, false];
};

