package dice

import (
	"fmt"
	"regexp"
	"strconv"
	"strings"
)

var (
	diePattern  = regexp.MustCompile(`(?i)^\s*(\d*)\s*d\s*(\d+)`)
	modPattern  = regexp.MustCompile(`(?i)^\s*([+-]\s*\d+)`)
	advPattern  = regexp.MustCompile(`(?i)^\s*\((adv|dis)\)`)
	plusPattern = regexp.MustCompile(`(?i)^\s*\+`)
)

func Parse(roll string) (RollConfig, error) {
	input := roll
	rc := RollConfig{
		Components: []RollComponent{},
		Modifier:   0,
		Advantage:  0,
	}
	for len(input) > 0 {
		switch {
		case diePattern.MatchString(input):
			m := diePattern.FindString(input)
			input = input[len(m):]
			match := strings.TrimSpace(m)
			match = strings.ToLower(match)
			parts := strings.Split(match, "d")
			if len(parts) != 2 {
				return rc, fmt.Errorf("invalid die format: %s", match)
			}
			parts[0] = strings.TrimSpace(parts[0])
			parts[1] = strings.TrimSpace(parts[1])

			count, err := strconv.Atoi(parts[0])
			if err != nil {
				return rc, fmt.Errorf("invalid die count in: %s", match)
			}
			die, err := strconv.Atoi(parts[1])
			if err != nil {
				return rc, fmt.Errorf("invalid die type in: %s", match)
			}
			rc.Components = append(rc.Components, RollComponent{
				Die:   DieType(die),
				Count: count,
			})
		case modPattern.MatchString(input):
			m := modPattern.FindString(input)
			input = input[len(m):]
			match := strings.TrimSpace(m)
			mod, err := strconv.Atoi(match)
			if err != nil {
				return rc, fmt.Errorf("invalid modifier in: %s", match)
			}
			rc.Modifier += mod
		case advPattern.MatchString(input):
			m := advPattern.FindString(input)
			match := strings.TrimSpace(m)
			if match == "(adv)" {
				rc.Advantage = Advantage
			} else {
				rc.Advantage = Disadvantage
			}
			input = input[len(m):]
		default:
			return rc, fmt.Errorf("unexpected input: %s", input)
		}
	}
	return rc, nil
}
